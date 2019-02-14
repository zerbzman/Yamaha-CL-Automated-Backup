/*
Yamaha CL Backup Console To File
Description: This is used to automate backing up of a CL5 console.
Author: Brent Zerbe
Created on: 20190121
Modified on: 20190214
Version: 1.2
// TODO: add pattern checking for ipaddress input
// TODO: add support for duplicate save files
// TODO: Multiple console support

1.2 notes
- added save config file
- added ipaddress input
- added console name
- added path input for save files
- added a timeout if something went wrong
- added a console ipaddress checker
- added a progress indicator
- added some reliabilty to the script in case you accidentally clicked out or started doing something else
- added notifications for success and errors
- added a check to see if CL Editor is installed
1.1 notes
- added a wait for the console sync

*/

var path
var storePath
var process
var clEditor
var app = Application.currentApplication()
app.includeStandardAdditions = true

//check if CL Editor is installed
try {
  clEditor = Application("CL Editor")
} catch (e) {
  alert("Can't find CL Editor", "Please install CL Editor in the Applications folder. You can download it from https://usa.yamaha.com/support/updates/cl_edt_mac.html", true)
  throw "Not Installed"
}

var scriptConfig = {}

main()

function main() {
  //see if settings are made
  try {
    scriptConfig = getScriptConfig()
  } catch (e) {
    scriptConfig = setupScript()
  }
  //check to see if the console is on or responding
  if (isConsoleConnected()) {
    try {
      var steps = 9
      Progress.totalUnitCount = steps
      Progress.completedUnitCount = 0
      Progress.description = "Setting Up..."
      Progress.additionalDescription = "Preparing to process."

      //step one and two
      clEditor.quit()
      Progress.additionalDescription = "Quiting CL Editor just in case"
      Progress.completedUnitCount++
      clEditor.activate()
      Progress.additionalDescription = "Opening CL Editor"
      Progress.completedUnitCount++

      var systemEvents = Application('System Events')
      process = systemEvents.processes['CL Editor']

      //step 3
      Progress.additionalDescription = "Inputing Console Address"
      Progress.completedUnitCount++
      //maybe try to close all the windows first
      delay(2)
      process.menuBars[0].menuBarItems[4].menus[0].menuItems[1].click()

      //first go to the setup screen
      process.menuBars[0].menuBarItems[2].menus[0].menuItems[8].click()

      //enter the ip Address
      var split = scriptConfig.ipAddress.split(".")
      clEditor.activate()
      for (number of split) {
        delay(.2)
        systemEvents.keystroke(number)
        //then tab
        systemEvents.keyCode(48)
      }
      systemEvents.keyCode(36)


      delay(3)
      //step 5
      Progress.additionalDescription = "Synchronizing the Console: This may take a while"
      Progress.completedUnitCount++
      //select the menu bar item "Synchronization"
      //systemEvents.keystroke('0', { using: 'command down' }) this isn't reliable
      process.menuBars[0].menuBarItems[5].menus[0].menuItems[0].click()
      delay(.2)
      clEditor.activate()
      systemEvents.keyCode(36)
      delay(.5)
      process.visible = false

      if (!waitForConsoleSync()) {
        throw "Console Sync Timeout: Something took way too long"
      }
      process.visible = true

      //step 6
      Progress.additionalDescription = "Changing the save Settings."
      Progress.completedUnitCount++
      clEditor.activate()
      delay(2)
      process.menuBars[0].menuBarItems[2].menus[0].menuItems[3].click()
      delay(1)
      var saveName = ""
      process.windows[0].textFields[0].value = saveName
      //then click Save As...

      //get the date/time
      var date = new Date()
      //save format
      // BU-{Device Name}-{Device Location or name}-20190131
      var month = (date.getMonth() + 1) + ""

      var saveName = `BU-${scriptConfig.consoleName}-${date.getFullYear()}${month.padStart(2, "0")}${date.getDate()}`

      delay(0.2)
      process.windows[0].textFields[0].value = saveName
      clEditor.activate()
      delay(0.2)
      systemEvents.keystroke('g', {
        using: ['command down', 'shift down']
      }) // Open the GoTo Dialog

      delay(0.5)

      //save in Documents->FOH-CL5
      clEditor.activate() //make sure the screen is on top
      //step 7
      Progress.additionalDescription = "Saving the Console File."
      Progress.completedUnitCount++
      systemEvents.keystroke(scriptConfig.consoleSavePath)
      delay(0.2)
      systemEvents.keyCode(36)
      delay(0.4)
      systemEvents.keyCode(36)

      //Overwrite if asked
      delay(0.4)
      clEditor.activate()
      systemEvents.keyCode(48)
      systemEvents.keyCode(36)

      //close the program
      //I had to do command q instead of clEditor.quit() because I couldn't get it to hit the no don't save button
      //step 8
      delay(1)
      Progress.additionalDescription = "Quiting CL Editor"
      Progress.completedUnitCount++
      clEditor.activate()
      systemEvents.keystroke('q', {
        using: 'command down'
      })
      delay(.2)
      systemEvents.keyCode(36)
      Progress.completedUnitCount++
      //show a notification or something to alert the user that the console isn't on
      app.displayNotification('Continue on', {
        withTitle: 'Success',
        subtitle: `${saveName} was saved.`
      })
    } catch (e) {
      app.displayNotification('The console file did not get saved.', {
        withTitle: e.toString(),
        subtitle: 'Error'
      })
    }
  } else {
    //show a notification or something to alert the user that the console isn't on
    app.displayNotification('Check to make sure the ipAddress is correct or a cable is unplugged.', {
      withTitle: 'Could not reach the console.',
      subtitle: 'Connection Error'
    })
  }


}

function waitForConsoleSync(time = 5) {
  var defaultWait = 5
  var waitTime = 180 //timeout after 3 minutes
  delay(defaultWait)
  if (time < waitTime) {
    if (process.windows.length !== 1) {
      return true
    } else {
      return waitForConsoleSync((time + defaultWait))
    }
  } else {
    return false
  }
}

function isConsoleConnected() {
  var shell = `ping -c 1 -W 1 ${scriptConfig.ipAddress} > /dev/null 2>&1 && echo "true" || echo "false";`
  var result = app.doShellScript(shell)
  if (result === "true") {
    return true
  } else {
    return false
  }
}

function alert(text, informationalText, critical = false) {
  var options = {}
  if (informationalText) options.message = informationalText
  if (critical) options.as = "critical"
  app.displayAlert(text, options)
}

function setupScript() {
  //ask the user for the ipaddress
  var ipAddress = prompt("What is the ipaddress of the mixer?")
  // TODO: setup some sort of format checker

  var consoleName = prompt("What do you want to name the mixer?")

  //ask the user where to save the console files
  var consoleSavePath = app.chooseFolder({
    withPrompt: "What folder do you want to save all the console files to?"
  })

  var data = {
    ipAddress: ipAddress,
    consoleName: consoleName,
    consoleSavePath: consoleSavePath.toString()
  }
  //store the file as a json object
  writeTextToFile(JSON.stringify(data), path, true)
  return data
}

function getCurrentScriptName() {
  //stub until I figure out how to get the current script name
  return "settings-cl-backup-tool"
}

function getScriptConfig() {
  path = `${app.pathTo("home folder")}/Documents/${getCurrentScriptName()}.txt`
  return JSON.parse(readFile(path))
}

function prompt(text, defaultAnswer) {
  var options = {
    defaultAnswer: defaultAnswer || ''
  }
  try {
    return app.displayDialog(text, options).textReturned
  } catch (e) {
    return null
  }
}

function readFile(file) {
  // Convert the file to a string
  var fileString = file.toString()

  // Read the file and return its contents
  return app.read(Path(fileString))
}

function writeTextToFile(text, file, overwriteExistingContent) {
  try {

    // Convert the file to a string
    var fileString = file.toString()

    // Open the file for writing
    var openedFile = app.openForAccess(Path(fileString), {
      writePermission: true
    })

    // Clear the file if content should be overwritten
    if (overwriteExistingContent) {
      app.setEof(openedFile, {
        to: 0
      })
    }
    // Write the new content to the file
    app.write(text, {
      to: openedFile,
      startingAt: app.getEof(openedFile)
    })

    // Close the file
    app.closeAccess(openedFile)

    // Return a boolean indicating that writing was successful
    return true
  } catch (error) {

    try {
      // Close the file
      app.closeAccess(file)
    } catch (error) {
      // Report the error is closing failed
      console.log(`Couldn't close file: ${error}`)
    }

    // Return a boolean indicating that writing was successful
    return false
  }
}
