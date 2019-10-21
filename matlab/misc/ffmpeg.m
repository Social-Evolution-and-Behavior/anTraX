function f=ffmpeg()


switch computer
    case 'MACI64'
        f = '/usr/local/bin/ffmpeg';
    case 'GLNXA64'
        f = '/usr/bin/ffmpeg';
end

% hack to check if we are on rockefeller hpc
if isfolder('/ru-auth/local/home/agal')
    f = '/ru-auth/local/home/agal/scratch/software/miniconda3/bin/ffmpeg';
end
