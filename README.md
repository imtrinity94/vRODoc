### Tutorial Video coming soon...

# <img width="211" alt="vRODoc (2)" src="https://user-images.githubusercontent.com/7029361/147040227-c5e64b5e-7e0c-4a42-833b-f225d88c88af.png"> 
### Convert vRO Actions to JSDoc to Github/Gitlab Pages
![Orange Ebb and Flow Abstract LinkedIn Banner](https://user-images.githubusercontent.com/7029361/147237254-83ff1bd6-6ae3-4147-9484-16e439f1905e.png)

This mechanism allows vRO Actions to be converted to JSDoc annotated Pure Javascript Code without even using any JSdoc annotation inside vRO. This mechanism intelligently fetches the funtionName, version, inputs and outputs from the vRO Actions itself and create JSDoc comments on basis of it.

Read this article: https://www.linkedin.com/pulse/vrodoc-convert-vro-actions-js-annotated-javascript-post-goyal

![vrodoc_process - Copy](https://user-images.githubusercontent.com/7029361/147050088-5fe238b1-f768-4199-ae7d-af3e756927e8.jpg)

### Installation

* Just run this command in your Powershell
```
Install-Script -Name vRODoc
```
* or you can also download this repo directly

### Prerequisite

* Install npm (download node.js installer) and jsdoc (npm install jsdoc)
* Connection to vRO Server where vRO action package is created (ping fqdn-of-vro-server)
* Any Recent version of Powershell

## How to run

- Go to the downloaded vrodoc_script.ps1 file and edit it to pass the connection related parameters inside it. 
- Open Powershell editor at that location and just execute it using .\exact_filename_of_vRODoc.ps1

### Example 

Let's say you created a simple action in vRO. Now you want that action to be documented. vRODoc has the capability to convert your action into a pure JS code with JSDoc annotations as you can see in the comments of this below mentioned JS code nd then will convert it into a .html page that will be a part of your JSDoc website.

```javascript
/**
 * @function getAllDesktopsForAUserInPool
 * @version 1.8.12
 * @param {string} poolName 
 * @param {string} username 
 * @returns {string}
 */
funtion getAllDesktopsForAUserInPool(poolName,userName){
     var DAConfiguration = System.getModule("com.mayank.actions").getDAConfigurationElement();
     var podConfiguration = System.getModule("com.mayank.actions").getPodConfigurationElement();
     var daUser = System.getModule("com.mayank.actions").getDA();
     var podAlias = System.getModule("com.vmware.library.view.configuration").getDefaultOrFirstPod(DAConfiguration, daUser);
     var machine = System.getModule("com.vmware.library.view.assignment").getAssignedMachine(poolName, podAlias, username, podConfiguration);
     if (machine)
          return machine.name;
};
```
<h6>Here, all the JSDoc comments are derived from vRO Action itself. There is no additional metadata/comment ever added while this vRO action was formed. Hence, it gives us a out-of-the-box funtionality. </h6>

### Contributing
If you find any issue with the current scripts, you can [create a issue.](https://github.com/imtrinity94/vRODoc/issues/new)

If you have any other scripts that you want to share, you can [create a pull request.](https://github.com/imtrinity94/vRODoc/compare)



[![SHARINGISCARING](http://ForTheBadge.com/images/badges/built-with-love.svg)](https://github.com/imtrinity94/vRODoc) <br>
<img src="https://user-images.githubusercontent.com/7029361/126627909-e7ea306a-a3cc-45e4-9be9-d22e1277fcc9.png" width="180" height="123">
