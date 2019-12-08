function ttable = load_tracklet_table(Trck, movlist)


if nargin<2
    movlist = Trck.movlist;
end

ttable = {};

for m=movlist    
   file = [Trck.trackingdir,'antdata',filesep,'tracklets_table_',num2str(m),'_',num2str(m),'.csv'];
   if exist(file,'file')
    ttable{end+1} = readtable(file); 
   end
end

ttable = cat(1,ttable{:});