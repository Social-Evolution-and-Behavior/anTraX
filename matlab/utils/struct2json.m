function struct2json(s,file)

fid = fopen(file,'w');

flds = fieldnames(s);

fprintf(fid, '{\n');

for i=1:length(flds)-1
   v =  s.(flds{i});
   if isa(v,'function_handle')
       v = func2str(v);
   end
   str = jsonencode(v);
   fprintf(fid,['\t','"',flds{i},'":',str,',\n']);
    
end

v =  s.(flds{end});
if isa(v,'function_handle')
    v = func2str(v);
end
str = jsonencode(v);
fprintf(fid,['\t','"',flds{i},'":',str,'\n']);

fprintf(fid, '}\n');

fclose(fid);