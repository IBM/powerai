The StructuralBioInformatics Python Library
===========================================

The **SBI** python library is a continuous work in progress that clusters functionalities to work with data derived from PDB,
from creating a local PDB repository to do *real* Blast searches over PDB sequences (i.e. sequences of the really crystallized protein
sections) to perform a simply split chains (separate the sections of a PDB file).

You can start to play by reading a PDB using the following command:

.. code-block:: python

    from SBI.structure import PDB
    newPDBobject = PDB('pdbfilename')

The library **is not exempt of bugs** (probably), and can not be considered a final version. This means that one must use it at its own risk.
And, while new functionalities are bound to appear, others might disappear at any given moment. Any comments, complains or bug reports can be
addressed in the corresponding sections.

Versions of this library lower than v0.3 are python2 only.