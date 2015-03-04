# CoreDataStackSetup
A rough example of how to set up a Core Data stack based on the talk by Marcus Zarra ([@mzarra](https://twitter.com/mzarra)) at MCE 2015 (https://www.youtube.com/watch?v=ckbke8vjHMw).

**This code has not been checked by or approved by Marcus, it is simply my interpretation of his talk.**

## Points To Note

* A good approach to setting the Core Data stack up is to configure your UI but disable or hide elements which cannot function until the stack setup is complete. Then call setupCoreDataStackWithCompletionHandler: which uses a block-based handler to return whether this was successful or not. If setup was successful you can enable and show the UI elements and refresh tables, etc.
* OTSMainViewController includes an addDataItem: method which allows you to add single items to the database. Each time an item is added the MOC performs a save.
* OTSMainViewController also includes an addMultipleDataItems: method which adds several items to the database on a separate MOC which is a child of the main thread MOC.  This method shows how to create a child MOC, and use its performBlock: method to do data manipulation without affecting the main thread MOC.
