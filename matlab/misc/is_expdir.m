function is = is_expdir(d,init_only)

% find expdir with initialized sessions
if ~isfolder(d)
    is = false;
    return 
end

if init_only
    is = ~isempty(find_sessions(d));
else
    report('E','Not yet implemented')
end

