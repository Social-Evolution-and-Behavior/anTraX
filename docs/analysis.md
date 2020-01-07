### The results files organization

### Loading tracking results in Python


```python
from antrax import *

ex = axExperiment(<expdir>, session=None)
antdata = axAntData(ex, movlist=None, antlist=None, colony=None)

```

### Loading tracking results in MATLAB

```matlab
ex = trhandles.load(<expdir>, session=None)
antdata = loadxy(ex, 'movlist', movlist, 'colony', colony)
```