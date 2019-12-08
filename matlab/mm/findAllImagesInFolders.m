function images = findAllImagesInFolders(folderName,fileType,frontConstraint)
%finds all images within 'folderName' (recursively) whose names end in 
%'fileType' and start with 'frontConstraint

    if nargin==1
        fileType = '.avi';
    end
    
    if nargin < 3 || isempty(frontConstraint) == 1
        frontConstraint = '';
    end
    
    
    if folderName(end) ~= '/'
        folderName = strcat(folderName, '/');
    end
    
    %[~,temp] = system(['ls ' folderName '/' frontConstraint '*' fileType]);
    %
    %images = regexp(temp,'\n','split')';
    %imageLengths = returnCellLengths(images);
    %images = images(imageLengths > length(fileType));
    
    images = dir([folderName,'*',fileType]);
    images = {images.name};
    for i=1:length(images)
        images{i}=[folderName,images{i}];
    end
    