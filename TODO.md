# Future Goals

### To implement

- Preview scrolling
- Async fuzzy engine if possible.
- add handler for user to listen to prompt change event
- update readme.md


### To test

- Add set\_data function for every resource.
- Add get\_current\_selection function for prompt resources.
- Add setPromptText function for prompt resources.
- get an init\_text for prompt initials
- Add option for close on buffer leave to be optional
- Handle lazy rendering selection well.
- Add sorter class to provide choice over fuzzy algorithm.
- better selection strategy in manager
- fuzzy engine should not contain prompt
- better strategy for set\_data function for fuzzy engines.
- Add possibilities for different type of fuzzy engines.
     (like execute job on each click)
- Add a repeated execution handler(good for very large and intense process
	because single execution fuzzy engine is not fully async)

### Currently working on


### Seems hard
- Add set\_prompt function for prompt resources.
- Add get\_prompt function for prompt resources. (Easy but waste if set\_prompt
is hard)
