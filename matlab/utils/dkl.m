function d = dkl(h1,h2)

h1=h1(:);
h2=h2(:);

h1=h1/sum(h1);
h2=h2/sum(h2);

goodIdx = h1>0 & h2>0; 

d1 = sum(h1(goodIdx) .* log(h1(goodIdx) ./ h2(goodIdx)));
d2 = sum(h2(goodIdx) .* log(h2(goodIdx) ./ h1(goodIdx)));

d = (d1 + d2)/2;