function new_classifier(Trck,targetdir,name)

if nargin<3
    report('E','Usage: new_classifier(Trck,targetdir,name')
    return
end

if ~isfolder(targetdir)
    report('E','Could not find target directory')
    return
end

classdir = [targetdir,filesep,name,filesep];

if isfolder(classdir)
    report('E',['Directory with name ',name,' already exist in target directory'])
    return
end

mkdir(classdir)
mkdir([classdir,'examples'])
for i=1:length(Trck.allLabels)
    mkdir([classdir,'examples',filesep,Trck.allLabels{i}])
end

Trck.classdir=classdir;

