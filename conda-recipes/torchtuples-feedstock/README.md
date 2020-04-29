# torchtuples 

[![Python package](https://github.com/havakv/torchtuples/workflows/Python%20package/badge.svg)](https://github.com/havakv/torchtuples/actions)
[![PyPI](https://img.shields.io/pypi/v/torchtuples.svg)](https://pypi.org/project/torchtuples/)
![PyPI - Python Version](https://img.shields.io/pypi/pyversions/torchtuples.svg)
[![License](https://img.shields.io/badge/License-BSD%202--Clause-orange.svg)](https://github.com/havakv/torchtuples/blob/master/LICENSE)

**torchtuples** is a small python package for training PyTorch models.
It works equally well for `numpy arrays` and `torch tensors`.
One of the main benefits of **torchtuples** is that it handles data in the form of nested tuples (see [example below](#example)).


## Installation

**torchtuples** depends on [PyTorch](https://pytorch.org/get-started/locally/) which should be installed from [HERE](https://pytorch.org/get-started/locally/).

Next, **torchtuples** can be installed with pip:
```bash
pip install torchtuples
```
For the bleeding edge version, install directly from github (consider adding `--force-reinstall`):
```bash
pip install git+git://github.com/havakv/torchtuples.git
```
or by cloning the repo:
```bash
git clone https://github.com/havakv/torchtuples.git
cd torchtuples
python setup.py install
```

## Example

```python
import torch
from torch import nn
from torchtuples import Model, optim
```
Make a data set with three sets of covariates `x0`, `x1` and `x2`, and a target `y`.
The covariates are structured in a nested tuple `x`.
```python
n = 500
x0, x1, x2 = [torch.randn(n, 3) for _ in range(3)]
y = torch.randn(n, 1)
x = (x0, (x0, x1, x2))
```
Create a simple ReLU net that takes as input the tensor `x_tensor` and the tuple `x_tuple`. Note that `x_tuple` can be of arbitrary length. The tensors in `x_tuple` are passed through a layer `lin_tuple`, averaged, and concatenated with `x_tensor`.
We then pass our new tensor through the layer `lin_cat`.
```python
class Net(nn.Module):
    def __init__(self):
        super().__init__()
        self.lin_tuple = nn.Linear(3, 2)
        self.lin_cat = nn.Linear(5, 1)
        self.relu = nn.ReLU()

    def forward(self, x_tensor, x_tuple):
        x = [self.relu(self.lin_tuple(xi)) for xi in x_tuple]
        x = torch.stack(x).mean(0)
        x = torch.cat([x, x_tensor], dim=1)
        return self.lin_cat(x)

    def predict(self, x_tensor, x_tuple):
        x = self.forward(x_tensor, x_tuple)
        return torch.sigmoid(x)
```

We can now fit the model with
```python
model = Model(Net(), nn.MSELoss(), optim.SGD(0.01))
log = model.fit(x, y, batch_size=64, epochs=5)
```
and make predictions with either the `Net.predict` method
```python
preds = model.predict(x)
```
or with the `Net.forward` method
```python
preds = model.predict_net(x)
```

For more examples, see the [examples folder](https://github.com/havakv/torchtuples/tree/master/examples).
