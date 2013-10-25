HMMtoCSV
========

Convert a state representation of a Hidden Markov Model into a Transition.csv and Emission.csv that can be consumed by R

A note about the sample.hmm file
================================
It is completely ok to reference states ahead or behind a structure as long as those states will globallly exist at the end. For example, the last state could have a destination state of -37, which would translate to global state 1 from the 9th structures viewpoint.
