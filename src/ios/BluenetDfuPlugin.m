//
//  BluenetDfuPlugin.m
//  BluenetDfuPlugin
//
//  Created by Timothy Wu on 2015/5/14.
//  Copyright (c) 2015 Timothy Wu. All rights reserved.
//

#import "BluenetDfuPlugin.h"
#import <CoreBluetooth/Corebluetooth.h>
//#import "DFULibrary-Swift.h"
//#import <iOSDFULibrary/iOSDFULibrary.h>
//#import <iOSDFULibrary/iOSDFULibrary-Swift.h>
//#import <iOSDFULibrary/iOSDFULibrary-umbrella.h>
@import iOSDFULibrary;


NSString *const kProgress = @"progress";
NSString *const kStatus = @"status";
NSString *const kSpeed = @"speed";
NSString *const kAvgSpeed = @"avg_speed";


@interface BluenetDfuPlugin()<CBCentralManagerDelegate, LoggerDelegate, DFUServiceDelegate, DFUProgressDelegate>

@property (nonatomic, strong) NSString* callbackId;

@property (nonatomic, strong) CBCentralManager *centralManager;
@property (nonatomic, strong) CBPeripheralManager *peripheralManager;

@property (nonatomic, strong) DFUServiceController *controller;

@property (nonatomic, strong) NSMutableDictionary *resultDic;

@property (nonatomic, strong) NSString *address; //peripheral address

@property (nonatomic, strong) CDVInvokedUrlCommand *command;
@property (nonatomic, strong) NSString *filePath;
//@property (nonatomic, strong) CBPeripheral *peripheral;

@end


@implementation BluenetDfuPlugin

@synthesize centralManager = _centralManager;
@synthesize resultDic = _resultDic;


// This is not called for some reason.
- (instancetype)init {
    self = [super init];
    if (self) {
        self.callbackId = nil;
        [self initialize];
    }
    return self;
}

- (void)initialize {
    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
}

//- (CBCentralManager *) centralManager {
//    if (_centralManager == nil) {
//        // options may have something to do with updating in background or launch from background? See Randusing plugin.
//
//        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil];
//    }
//    return _centralManager;
//}

- (NSString *) firmwarePath{
    //    NSLog(@"path for index.html: %@", [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"]);
    //    NSLog(@"path for sdk: %@", [[NSBundle mainBundle] pathForResource:@"sdk11_lock_20161215_resDelay" ofType:@"zip"]);
    if (self.filePath) {
        return [self.filePath substringWithRange:NSMakeRange(7, self.filePath.length - 7)]; // get rid of file://
    } else {
        return [[NSBundle mainBundle] pathForResource:@"sdk11_lock_20161215_resDelay" ofType:@"zip"];
    }
}

- (NSMutableDictionary *)resultDic {
    if (!_resultDic) {
        _resultDic = [[NSMutableDictionary alloc] init];
    }
    return _resultDic;
}

//    self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil options:nil]; // options may have something to do with updating in background or launch from background? See Randusing plugin.

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

- (void)uploadFirmware:(CDVInvokedUrlCommand *)command
{
    NSLog(@"uploadFirmware called");
    NSDictionary *parameter = (NSDictionary *)command.arguments[0];
    self.address = parameter[@"address"];
    // NSString *name = parameter[@"name"]; // Ignore at the moment
    self.filePath = parameter[@"filePath"];
    
    self.callbackId = command.callbackId;
    self.command = command;
    
    [self initialize];
}


- (void)performDFUOnPeripheral:(CBPeripheral *) peripheral
{
    NSLog(@"performDFUOnPeripheral called");
    DFUServiceInitiator *initiator = [[DFUServiceInitiator alloc] initWithCentralManager: self.centralManager target:peripheral];
    
    //let firmware = DFUFirmware.init(urlToZipFile: NSURL(fileURLWithPath: path))
    DFUFirmware *firmware = [[DFUFirmware alloc] initWithUrlToZipFile:[NSURL fileURLWithPath:self.firmwarePath]];
    [initiator withFirmware:firmware];
    //    [initiator withFirmwareFile:firmware];
    initiator.forceDfu = [[[NSUserDefaults standardUserDefaults] valueForKey:@"dfu_force_dfu"] boolValue];
    //    initiator.packetReceiptNotificationParameter = [[[NSUserDefaults standardUserDefaults] valueForKey:@"dfu_number_of_packets"] intValue];
    initiator.packetReceiptNotificationParameter = 12;
    initiator.logger = self;
    initiator.delegate = self;
    initiator.progressDelegate = self;
    // initiator.peripheralSelector = ... // the default selector is used
    
    self.controller = [initiator start];
}

#pragma mark - DFUProgressDelegate
- (void)dfuProgressDidChangeFor:(NSInteger)part outOf:(NSInteger)totalParts to:(NSInteger)progress currentSpeedBytesPerSecond:(double)currentSpeedBytesPerSecond avgSpeedBytesPerSecond:(double)avgSpeedBytesPerSecond
{
    self.resultDic[kProgress] = [NSNumber numberWithFloat:(float) progress / 100.0f];
    self.resultDic[kSpeed] = [NSNumber numberWithDouble:currentSpeedBytesPerSecond];
    self.resultDic[kAvgSpeed] = [NSNumber numberWithDouble: avgSpeedBytesPerSecond];
    [self sendResult:self.resultDic];
}

#pragma mark - DFUServiceDelegate
-(void)dfuStateDidChangeTo:(enum DFUState)state
{
    switch (state) {
        case DFUStateConnecting:
            self.resultDic[kStatus] = @"connecting";
            break;
        case DFUStateStarting:
            self.resultDic[kStatus] = @"starting";
            break;
        case DFUStateEnablingDfuMode:
            self.resultDic[kStatus] = @"enablingDfuMode";
            break;
        case DFUStateUploading:
            self.resultDic[kStatus] = @"uploading";
            break;
        case DFUStateValidating:
            self.resultDic[kStatus] = @"validating";
            [self.resultDic removeObjectForKey:kProgress];
            [self.resultDic removeObjectForKey:kSpeed];
            [self.resultDic removeObjectForKey:kAvgSpeed];
            break;
        case DFUStateDisconnecting:
            self.resultDic[kStatus] = @"disconnecting";
            [self disconnectBluetooth];
            break;
        case DFUStateCompleted:
            self.resultDic[kStatus] = @"completed";
            break;
            
        case DFUStateAborted:
            self.resultDic[kStatus] = @"aborted";
            break;
    }
    
    [self sendResult:self.resultDic];
}

- (void)dfuError:(enum DFUError)error didOccurWithMessage:(NSString * _Nonnull)message
//- (void)didErrorOccur:(enum DFUError)error withMessage:(NSString * _Nonnull)message
{
    
    NSLog(@"Error %ld: %@", error, message);// \(error.rawValue): \(message)")
    /*
     DFUErrorRemoteSuccess = 1,
     DFUErrorRemoteInvalidState = 2,
     DFUErrorRemoteNotSupported = 3,
     DFUErrorRemoteDataExceedsLimit = 4,
     DFUErrorRemoteCrcError = 5,
     DFUErrorRemoteOperationFailed = 6,
     
     /// Providing the DFUFirmware is required.
     DFUErrorFileNotSpecified = 101,
     
     /// Given firmware file is not supported.
     DFUErrorFileInvalid = 102,
     
     /// Since SDK 7.0.0 the DFU Bootloader requires the extended Init Packet. For more details, see: http://infocenter.nordicsemi.com/topic/com.nordic.infocenter.sdk5.v11.0.0/bledfu_example_init.html?cp=4_0_0_4_2_1_1_3
     DFUErrorExtendedInitPacketRequired = 103,
     
     /// Before SDK 7.0.0 the init packet could have contained only 2-byte CRC value, and was optional. Providing an extended one instead would cause CRC error during validation (the bootloader assumes that the 2 first bytes of the init packet are the firmware CRC).
     DFUErrorInitPacketRequired = 104,
     DFUErrorFailedToConnect = 201,
     DFUErrorDeviceDisconnected = 202,
     DFUErrorServiceDiscoveryFailed = 301,
     DFUErrorDeviceNotSupported = 302,
     DFUErrorReadingVersionFailed = 303,
     DFUErrorEnablingControlPointFailed = 304,
     DFUErrorWritingCharacteristicFailed = 305,
     DFUErrorReceivingNotificatinoFailed = 306,
     DFUErrorUnsupportedResponse = 307,
     
     /// Error called during upload when the number of bytes sent is not equal to number of bytes confirmed in Packet Receipt Notification.
     DFUErrorBytesLost = 308,
     */
}

#pragma mark - LoggerDelegate
- (void)logWith:(enum LogLevel)level message:(NSString * _Nonnull)message {
    // nothing at the moment
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"central.state: %ld, address: %@", central.state, self.address);
    if (central.state == CBManagerStatePoweredOn)
    {
        CBPeripheral *peripheral = [self obtainPeripheralWithAddress:self.address command:self.command];
        if (peripheral) {
            [self performDFUOnPeripheral:peripheral];
        }
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self performDFUOnPeripheral:peripheral];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    
}


- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    
}

#pragma mark - Bluetooth device connection
- (void)disconnectBluetooth {
    
}


- (CBPeripheral *)obtainPeripheralWithAddress:(NSString *)address command: (CDVInvokedUrlCommand *)command {
    NSUUID *nsuuid = [[NSUUID UUID] initWithUUIDString:address];
    NSArray *peripherals = [self.centralManager retrievePeripheralsWithIdentifiers:@[nsuuid]];
    
    if (peripherals.count == 0) {
        NSDictionary *returnObj = [NSDictionary dictionaryWithObjectsAndKeys: @"uploadFirmware", @"error", @"Device not found", @"message", address, @"address", nil];
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:returnObj];
        [pluginResult setKeepCallbackAsBool:false];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return nil;
    }
    
    //Get the peripheral to connect
    return peripherals[0];
    
    // I think the initilizer connect the peripheral itself.
    //    [self.centralManager connectPeripheral:peripherals[0] options:nil];
}



#pragma mark - Commands to JS
- (void) sendResult:(NSMutableDictionary *)resultDic {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary: resultDic];
    [result setKeepCallback:@YES];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];
}


@end
