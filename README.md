# vRO Actions to JSDoc to Github/Gitlab Pages

This mechanism allows vRO Actions to be converted to JSDoc annotated Pure Javascript Code without even using any JSdoc annotatio in vRO. This mechanism intelligently fetches the funtionName, version, inputs and outputs from the vRO Actions itself and create comments on basis of it.

```javascript
/**
 * @function getAllDesktopsForAUserInPool
 * @version 0.0.0
 * @param {string} poolName 
 * @param {string} username 
 * @returns string
 */
var DAConfiguration = System.getModule("com.mayank.actions").getDAConfigurationElement();
var podConfiguration = System.getModule("com.mayank.actions").getPodConfigurationElement();
var daUser = System.getModule("com.mayank.actions").getDA();
var podAlias = System.getModule("com.vmware.library.view.configuration").getDefaultOrFirstPod(DAConfiguration, daUser);
var machine = System.getModule("com.vmware.library.view.assignment").getAssignedMachine(poolName, podAlias, username, podConfiguration);
if (machine)
     return machine.name;
```
Here, all the JSDoc is derived from vRO Action itself. There was not additional metadata/comment ever added while this vRO action was formed. Hence, it gives us a out-of-the-box funtionality.
![Untitled Diagram drawio (2)](https://user-images.githubusercontent.com/7029361/145952228-b555bc24-2507-4758-b72f-e92fd9b20bd1.png)
