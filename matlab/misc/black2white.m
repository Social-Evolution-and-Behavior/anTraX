function black2white(classdir)


% list all example files
files = dir([classdir,'examples/*/*png']);

for i=1:length(files)
    
    if rem(i,100)==0
        report('I',['Finished ',num2str(i),'/',num2str(length(files))])
    end
    I=imread([files(i).folder,filesep,files(i).name]);
    msk = repmat(max(I,[],3)==0,[1,1,3]);
    I(msk)=255;
    imwrite(I,[files(i).folder,filesep,files(i).name]);
    
end












