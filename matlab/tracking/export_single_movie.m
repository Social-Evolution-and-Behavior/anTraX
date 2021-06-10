function export_single_movie(expdir,m, varargin)

p = inputParser;
addRequired(p,'expdir',@(x) (ischar(x) && isfolder(x)) || isa(x,'trhandles'));
addRequired(p,'m',@(x) isnumeric(x)||ischar(x));
addParameter(p,'colony','');
addParameter(p,'untagged', false);
addParameter(p,'trackingdirname',[]);

% parse inputs
parse(p,expdir,m, varargin{:});

untagged = p.Results.untagged;
if ischar(untagged)
    untagged = strcmp(untagged, 'True');
end

Trck = trhandles.load(expdir,p.Results.trackingdirname);

colony = p.Results.colony;

if Trck.get_param('geometry_multi_colony')
    
    if isempty(colony)
        
        report('E','Colony argument is missing for multi colony experiment')
        return
        
    elseif isnumeric(colony)
        
        try
            colony = Trck.colony_labels{colony};
        catch
            report('E','Bad colony number')
            return
        end
        
    elseif ~ismember(colony,Trck.colony_labels)
        
        try
            colony = str2num(colony);
            colony = Trck.colony_labels{colony};
        catch
            report('E',['Unknown colony identifier ', colony])
            return
        end

    end

end


if ~ismember(m,Trck.graphlist)
    error('Movie doesnt have a tracklet graph')
end

G = Trck.loaddata(m,colony);
export_xy(G,'interpolate',false,'untagged',untagged);

report('G','Done')





