classdef ffreader < handle & matlab.mixin.SetGet
    
    properties
        
        file              % full path to video file
        p                 % pipe to ffmpeg process
        isopen=false      % True for open file
        info              % video info fields
        pos=0
        buf
        buf_f 
        buf_ix 
        buf_sz = 2
        
        max_frame_gap = 10;
        
    end
    
    
    properties (Dependent)
        
        NumberOfFrames
        FrameRate
        Duration
        Name
        CurrentTime
        Height
        Width
        
        
    end
    
    
    methods
        
        function obj = ffreader(file,bfsz)
            
            if strcmp(computer,'MACI64')
                if ~contains(getenv('PATH'),'/usr/local/bin')
                    setenv('PATH', [getenv('PATH') ':/usr/local/bin']);
                end
            end
            
            if nargin>1
                obj.buf_sz = bfsz;
            end
            
            
            % check if popenr exists and compiled
            if ~isdeployed && exist('popenr','file')~=3
                report('E', '===========================================')
                report('E', 'Please compile the popenr mex file')
                report('E', 'Refer to antTraX installation instructions')
                report('E', '===========================================')
                error('popenr does not exist')
            end
            
            obj.file = file;
            obj.collectInfo;
            obj.buf = zeros([obj.info.height,obj.info.width,obj.info.channels,obj.buf_sz],'uint8');
            obj.buf_f = zeros(obj.buf_sz,1);
            obj.buf_ix = 1;
            
        end
        
        function frame = read(self,f)
            
            if nargin<2
                f = self.pos+1;
            end
            
            if f>self.info.nframes
                report('E','requested frame number is higher than number of frames in file');
                frame=[];
                return
            end
            
            % first check if required frame is in buffer
            if ismember(f,self.buf_f)
                frame = self.buf(:,:,:,self.buf_f==f);
                return
            end
            
            % reopen pipe if frame is to far away
            if ~self.isopen || f<=self.pos || f>self.pos+self.max_frame_gap
                %report('I',['reopening pipe to video file: requested frame ',num2str(f),', last frame read is ',num2str(self.pos)])
                self.openPipe(f);
            elseif f>self.pos+1
                while f>self.pos+1
                    self.read();
                end
            end
            
            frame1 = uint8(popenr(self.p,self.info.framebytes,'uint8'));
            
            if isempty(frame1) || numel(frame1)< self.info.channels*self.info.width*self.info.height
                report('W',['ffreader: could not read frame #',num2str(f),' from file ',self.file]);
                report('W','ffreader: Trying to restart reader');
                self.openPipe(f);
                frame1 = uint8(popenr(self.p,self.info.framebytes,'uint8'));
                if isempty(frame1) || numel(frame1)< self.info.channels*self.info.width*self.info.height
                    report('E',['Failed -last good frame was ',num2str(self.pos)])
                    frame = [];
                    return
                else
                    report('I','Success')
                end
            end
            
            frame2 = reshape(frame1,[self.info.channels,self.info.width,self.info.height]);
            frame = permute(frame2,[3,2,1]);
            self.buf(:,:,:,self.buf_ix)=frame;
            self.buf_f(self.buf_ix)=f;
            self.buf_ix = self.buf_ix+1;
            if self.buf_ix>self.buf_sz
                self.buf_ix=1;
            end
            
            self.pos=self.pos+1;
        end
        
        function close(self)
            try
                popenr(self.p,-1);
            catch
            end
            self.isopen=false;
        end
        
        function delete(self)
            if self.isopen
                self.close();
            end
        end
    end
    
    
    methods (Access = private)
        
        function openPipe(self,f)
           
            [~,ffmpeg] = system('which ffmpeg');
            ffmpeg = ffmpeg(1:end-1);
            
            if ~isfile(ffmpeg)
                report('E', 'Could not locate ffmpeg')
                error('Could not locate ffmpeg')
            end

            if self.isopen
                %report('D',['closing pipe #',num2str(self.p)]);
                popenr(self.p,-1);
                self.isopen=false;
            end
            
            for i=1:10
                if nargin==1
                    self.p = popenr([ffmpeg,' -loglevel quiet -i "',self.file,'" -pix_fmt rgb24 -f image2pipe -vcodec rawvideo pipe:1']);
                    self.pos=0;
                else
                    ss = (f-1)/self.info.fps;
                    self.p = popenr([ffmpeg,' -loglevel quiet',' -ss ',num2str(ss),' -i "',self.file,'" -pix_fmt rgb24 -f image2pipe -vcodec rawvideo pipe:1']);
                    self.pos = f-1;
                end
                if ~isempty(self.p) && self.p>=0
                    %report('D',['opened pipe #',num2str(self.p)])
                    self.isopen=true;
                    break
                else
                    report('D',['failed to open pipe'])
                end
            end
        end
        
        function collectInfo(self)
            self.info = ffinfo(self.file);
%            k=0;
%            while isempty(self.info)
%                 try
%                     self.info = ffinfo(self.file);
%                 catch exception
%                     k=k+1;
%                     report('W','Get info failed, retrying')
%                     if k>10
%                         report('E', 'ffinfo failed 10 times')
%                         throw(exception)
%                     end
%                 end
%            end
            
        end
        
    end
    
    methods
        
        
        function n = get.NumberOfFrames(vr)
            
            n = vr.info.nframes;
            
        end
        
        function n = get.FrameRate(vr)
            
            n = vr.info.fps;
            
        end
        
        function n = get.Duration(vr)
            
            n = vr.info.duration;
            
        end
        
        function n = get.Width(vr)
            
            n = vr.info.width;
            
        end
        
        function n = get.Height(vr)
            
            n = vr.info.height;
            
        end

        function n = get.Name(vr)
            
            
            n = vr.file;
                        
        end
        
      
         
              
    end
    
    
end




