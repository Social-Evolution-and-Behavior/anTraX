function [passed,score] = filter_frames(trj)


% gather parameters
Trck = trj.Trck;
minAREA = Trck.get_param('thrsh_meanareamin');
maxAREA = Trck.get_param('thrsh_meanareamax');
maxECCENT = Trck.get_param('classification_maxECCENT');
minECCENT = Trck.get_param('classification_minECCENT');

e_minarea = (trj.rarea - minAREA)/minAREA;
e_maxarea = min([(- trj.rarea + maxAREA)/maxAREA,zeros(size(trj.rarea))],[],2);
e_maxeccent = (-trj.ECCENT + maxECCENT)/maxECCENT;
e_mineccent = (trj.ECCENT - minECCENT)/minECCENT;

score = 2.*sigmoid(e_minarea)...
    .*2.*sigmoid(e_maxarea)...
    .*2.*sigmoid(e_mineccent)...
    .*2.*sigmoid(e_maxeccent);

passed = e_minarea >=0 &...
    e_maxarea >=0 &...
    e_maxeccent >=0 &...
    e_mineccent >=0;