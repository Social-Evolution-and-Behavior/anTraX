function init_of_obj(Trck)


smoothness = Trck.get_param('linking_of_smoothness');
maxiter = Trck.get_param('linking_of_maxiter');

Trck.opticalFlow = opticalFlowHS('Smoothness',smoothness,'MaxIteration',maxiter);
