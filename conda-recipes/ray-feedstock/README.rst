.. image:: https://github.com/ray-project/ray/raw/master/doc/source/images/ray_header_logo.png

|

**Ray is a fast and simple framework for building and running distributed applications.**

Ray is packaged with the following libraries for accelerating machine learning workloads:

- `Tune`_: Scalable Hyperparameter Tuning
- `RLlib`_: Scalable Reinforcement Learning
- `Distributed Training <https://ray.readthedocs.io/en/latest/distributed_training.html>`__

Quick Start
-----------

Execute Python functions in parallel.

.. code-block:: python

    import ray
    ray.init()

    @ray.remote
    def f(x):
        return x * x

    futures = [f.remote(i) for i in range(4)]
    print(ray.get(futures))

To use Ray's actor model:

.. code-block:: python


    import ray
    ray.init()

    @ray.remote
    class Counter(object):
        def __init__(self):
            self.n = 0

        def increment(self):
            self.n += 1

        def read(self):
            return self.n

    counters = [Counter.remote() for i in range(4)]
    [c.increment.remote() for c in counters]
    futures = [c.read.remote() for c in counters]
    print(ray.get(futures))


Ray programs can run on a single machine, and can also seamlessly scale to large clusters. To execute the above Ray script in the cloud, just download `this configuration file <https://github.com/ray-project/ray/blob/master/python/ray/autoscaler/aws/example-full.yaml>`__, and run:

``ray submit [CLUSTER.YAML] example.py --start``

Read more about `launching clusters <https://ray.readthedocs.io/en/latest/autoscaling.html>`_.

More Information
----------------

- `Documentation`_
- `Tutorial`_
- `Blog`_
- `Ray paper`_
- `Ray HotOS paper`_
- `RLlib paper`_
- `Tune paper`_

.. _`Documentation`: http://ray.readthedocs.io/en/latest/index.html
.. _`Tutorial`: https://github.com/ray-project/tutorial
.. _`Blog`: https://ray-project.github.io/
.. _`Ray paper`: https://arxiv.org/abs/1712.05889
.. _`Ray HotOS paper`: https://arxiv.org/abs/1703.03924
.. _`RLlib paper`: https://arxiv.org/abs/1712.09381
.. _`Tune paper`: https://arxiv.org/abs/1807.05118

Getting Involved
----------------

- `ray-dev@googlegroups.com`_: For discussions about development or any general
  questions.
- `StackOverflow`_: For questions about how to use Ray.
- `GitHub Issues`_: For reporting bugs and feature requests.
- `Pull Requests`_: For submitting code contributions.
- `Meetup Group`_: Join our meetup group.
- `Community Slack`_: Join our Slack workspace.
- `Twitter`_: Follow updates on Twitter.

.. _`ray-dev@googlegroups.com`: https://groups.google.com/forum/#!forum/ray-dev
.. _`GitHub Issues`: https://github.com/ray-project/ray/issues
.. _`StackOverflow`: https://stackoverflow.com/questions/tagged/ray
.. _`Pull Requests`: https://github.com/ray-project/ray/pulls
.. _`Meetup Group`: https://www.meetup.com/Bay-Area-Ray-Meetup/
.. _`Community Slack`: https://forms.gle/9TSdDYUgxYs8SA9e8
.. _`Twitter`: https://twitter.com/raydistributed
