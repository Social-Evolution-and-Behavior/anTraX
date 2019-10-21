function [lastmssg] = report(type,msg,varargin)
% asaf gal
% 03/12/15

% jonathan saragosti
% 04/03/16
% remove '%' in msg
% 02/14/17
% modification to be able to erase last line:
% Example:
% [last_msg] = report('G','Some message');
% pause(2);
% [last_msg] = report('G','New message','EraseLastMessage',last_msg);

p = inputParser();
addRequired(p,'type',@ischar)
addRequired(p,'msg',@ischar)
% if this is not an empty string this will delete the last message)
addParameter(p,'removePercent',true,@islogical);
addParameter(p,'EraseLastMessage','',@ischar);

parse(p,type,msg,varargin{:})


%reverseStr = repmat(sprintf('\b'), 1, length(p.Results.EraseLastMessage));


if p.Results.removePercent 
    msg(ismember(msg,'%')) = [];
    reverseStr = repmat(sprintf('\b'), 1, length(p.Results.EraseLastMessage)-1);
else
    reverseStr = repmat(sprintf('\b'), 1, length(p.Results.EraseLastMessage)-1);
end
fprintf(reverseStr);
funcstr = '';
% uncomment this to get function name in report
% % % st = dbstack;
% % % if length(st)>1
% % %    funcstr = ['(',st(2).name,') '];
% % % end

% displays a report in the command window with color code
% Use in stead of waitbar
t = datestr(datetime('now'),'HH:MM:SS');

% warning - orange
if type=='W'
    fullmsg = [t,' -W- ',funcstr,msg,'\n'];
    cprintf('*[1,0.6,0]',fullmsg);
% error - red
elseif type=='E'
    fullmsg = [t,' -E- ',funcstr,msg,'\n'];
    cprintf('*[1,0,0]',fullmsg);
% good news - green
elseif type=='G'
    fullmsg = [t,' -G- ',funcstr,msg,'\n'];
    cprintf('*[0.2,0.8,0]',fullmsg);
% developer messages
elseif type=='M'
    fullmsg = [t,' -M- ',funcstr,msg,'\n'];
    cprintf('*[0.2,0.2,0.8]',fullmsg);
% obsolete file warning
elseif type=='O'
    st = dbstack;
    obsFunc = ['(',st(2).name,') '];
    callFunc = ['(',st(3).name,') '];
    fullmsg = [t,' -O- *** Use of obsolete function ''',obsFunc,''' in function ''',callFunc,''' ***\n'];
    cprintf('*[1,0,0]',fullmsg);
elseif type=='D'
    fullmsg = [t,' -D- ',funcstr,msg,'\n'];
    % uncomment for debug reports
    cprintf('*[0.2,0.4,0.8]',fullmsg);
% unknow - black
elseif type=='WB'
    fullmsg = [t ' - ' funcstr,msg,'\n'];
    fprintf(fullmsg);
else
    % PLEASE LEAVE GREY COLOR SO THAT IT'S VISIBLE WITH A BLACK OR WHITE COMMAND
    % WINDOW
    fullmsg = [t,' -I- ',funcstr,msg,'\n'];
    %cprintf('*[0.5 0.5 0.5]',fullmsg);
    fprintf(fullmsg);
end

if nargout == 1
    lastmssg = fullmsg;
end


