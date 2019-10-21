function f=ffprobe()


switch computer
    case 'MACI64'
        f = '/usr/local/bin/ffprobe';
    case 'GLNXA64'
        f = '/usr/bin/ffprobe';
end

% hack to check if we are on rockefeller hpc
if isfolder('/ru-auth/local/home/agal')
    f = '/ru-auth/local/home/agal/scratch/software/miniconda3/bin/ffprobe';
end
