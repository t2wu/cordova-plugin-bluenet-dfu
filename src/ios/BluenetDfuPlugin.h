#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>

@interface BluenetDfuPlugin : CDVPlugin


//@property (readonly, assign) BOOL isRunning;




- (instancetype)init;


/*
 parameter: {
 'address': String, bluetooth address of the device (required)
 'name': String, name of the device (required)
 'filePath': String, absolut path of the file which should be uploaded (required*)
 'fileUri': String, absolut path as an Uri, has to be encoded with encodeUri() (required*)
 'fileType': Integer, type of uploaded file, see Android DFU Library for details (optional, default TYPE_APPLICATION)
 'initFilePath': String, absolut path of the init file (optional*, default null which means no init file used)
 'initFileUri': String, absolut path of the init file as an Uri, has to be encoded with encodeUri() (optional*)
 'keepBond': Boolean, see Android DFU Library for details (optional, default false)
 }
 */


/*
 return: {
 'status': String, status, such as connecting, disconnecting, progress, completed, etc.
 'progress': Integer, percentage of current upload prograss, min 1, max 100, (only if status == progress)
 'speed': Float, upload speed in Mb/s (only if status == progress)
 'avg_speed': Float, average upload speed in Mb/s (only if status == progress)
 }
 */

//- (void)initialize;
- (void)uploadFirmware:(CDVInvokedUrlCommand*)command;

@end
