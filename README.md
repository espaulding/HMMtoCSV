HMMtoCSV
========

Convert a state representation of a Hidden Markov Model into a Transition.csv and Emission.csv that can be consumed by R

A note about the sample.hmm file
================================
It is completely ok to reference states ahead or behind a structure as long as those states will exist. For example, the last state could have a destination state of -37, which would translate to global state 1 from the 9th structure's viewpoint.

It's equally ok to reference a state that doesn't yet exist by the current structures count, which can be seen near the end of each structure as they transition forward.

When states are normalized at the end if any state destination is less than 1 or greater than the number of states, the script will fail with an error message explaining which state destination is invalid.

.HMM file structure definition
==============================

Block of text starting with (#state character definition)
and ending with (#end scd)

Block of text starting with (#model structures)
and ending with (#end model)

These blocks don't need to be in any particular order, but they must both exist.

state characters
----------------
* Each state character must have emission pobabilites that sum to 1
* syntax (state character|probability->emission)
* there can be any number of probability->emission pairs, which must be separated by semi colons

model structures
----------------
* Each structure starts with a header line and is ended with #
* Header line syntax (>structure_number|structure_name//comment)
* the comments can not contain newline characters
* it's ok to skip numbers when numbering structures, and the structures will always be added to the model from the smallest structure_number to the largest.

syntax of a state within a structure
------------------------------------
* (relative_state_number|state_character|probability->destination_state)

* relative_state_numbers can be in any order, but they must start at 1 and not skip any numbers.
 For example, 1, 2, 3 and 1, 3, 2 are both valid, but 1, 3, 4 is not.

* state_character must be defined in the state character section or the script will fail and return an error saying which state is using an undefined state character

* probability->destination_state pairs must always sum to a probability of 1 for each state.
There can be any number of pairs and they should be separated by semi colons in the following form.
p->d;p->d;p->d

