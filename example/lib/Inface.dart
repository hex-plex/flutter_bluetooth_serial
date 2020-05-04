import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import './BluetoothDeviceListEntry.dart';
import './DiscoveryPage.dart';
import './SelectBondedDevicePage.dart';
import './ChatPage.dart';
import './BackgroundCollectingTask.dart';
import './BackgroundCollectedPage.dart';

class MainPage extends StatefulWidget {
  final bool start =true;
  @override
  _MainPage createState() => new _MainPage();
}
class _MainPage extends State<MainPage> {
  BluetoothState _bluetoothState = BluetoothState.UNKNOWN;
  
  StreamSubscription<BluetoothDiscoveryResult> _streamSubscription;
  List<BluetoothDiscoveryResult> results = List<BluetoothDiscoveryResult>();
  bool isDiscovering = false;
  String _address = "...";
  String _name = "...";

  Timer _discoverableTimeoutTimer;
  int _discoverableTimeoutSecondsLeft = 0;

  BackgroundCollectingTask _collectingTask;

  bool _autoAcceptPairingRequests = false;
  
  @override
  void initState() {
    super.initState();



                
    // Get current state
    FlutterBluetoothSerial.instance.state.then((state) {
      setState(() {
        _bluetoothState = state;
      });
    });
    Future.doWhile(() async {
      // Wait if adapter not enabled
      if (await FlutterBluetoothSerial.instance.isEnabled) {
        return false;
      }
      await Future.delayed(Duration(milliseconds: 0xDD));
      return true;
    }).then((_) {
      // Update the address field
      FlutterBluetoothSerial.instance.address.then((address) {
        setState(() {
          _address = address;
        });
      });
    });

    FlutterBluetoothSerial.instance.name.then((name) {
      setState(() {
        _name = name;
      });
    });

    // Listen for futher state changes
    FlutterBluetoothSerial.instance
        .onStateChanged()
        .listen((BluetoothState state) {
      setState(() {
        _bluetoothState = state;

        _discoverableTimeoutTimer = null;
        _discoverableTimeoutSecondsLeft = 0;
      });
    });
  }

 _MainPage(){
     future() async {
                  if (!_bluetoothState.isEnabled){
                    await FlutterBluetoothSerial.instance.requestEnable();
                }}
    future().then((_) {
                  setState(() {});
      });
    if(_bluetoothState.isEnabled){
      if (isDiscovering) {
        _startDiscovery();
    }
    }
   }
   void _restartDiscovery() {
    setState(() {
      results.clear();
      isDiscovering = true;
    });

    _startDiscovery();
  }

  void _startDiscovery() {
    _streamSubscription =
        FlutterBluetoothSerial.instance.startDiscovery().listen((r) {
      setState(() {
        results.add(r);
      });
    });

    _streamSubscription.onDone(() {
      setState(() {
        isDiscovering = false;
      });
    });
  }

  @override
  void dispose() {
    FlutterBluetoothSerial.instance.setPairingRequestHandler(null);
    _collectingTask?.dispose();
    _discoverableTimeoutTimer?.cancel();
    _streamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KyuKey Bluetooth Interface'),
        backgroundColor: Colors.amber[900],
        actions: <Widget>[IconButton(
                  icon: Icon(Icons.settings),
                  onPressed: (){
                  FlutterBluetoothSerial.instance.openSettings();
                },
                )
        ],
      ),
      body: Container(
        child: ListView(
          children: <Widget>[
            Divider(),
            SwitchListTile(
              title: const Text('Enable Bluetooth'),
              value: _bluetoothState.isEnabled,
              activeColor: Colors.amberAccent[400],
              onChanged: (bool value) {
                // Do the request and update with the true value then
                future() async {
                  // async lambda seems to not working
                  if (value)
                    await FlutterBluetoothSerial.instance.requestEnable();
                  else
                    await FlutterBluetoothSerial.instance.requestDisable();
                }

                future().then((_) {
                  setState(() {});
                });
              },
            ),
            Divider(),
            SwitchListTile(
              title: const Text('Auto-try specific pin when pairing'),
              subtitle: const Text('Pin 1234'),
              activeColor: Colors.amberAccent[400],
              value: _autoAcceptPairingRequests,
              onChanged: (bool value) {
                setState(() {
                  _autoAcceptPairingRequests = value;
                });
                if (value) {
                  FlutterBluetoothSerial.instance.setPairingRequestHandler(
                      (BluetoothPairingRequest request) {
                    print("Trying to auto-pair with Pin 1234");
                    if (request.pairingVariant == PairingVariant.Pin) {
                      return Future.value("1234");
                    }
                    return null;
                  });
                } else {
                  FlutterBluetoothSerial.instance
                      .setPairingRequestHandler(null);
                }
              },
            ),
            ListTile(
              title: RaisedButton(
                  child: const Text('Explore discovered devices'),
                  onPressed: () async {
                    final BluetoothDevice selectedDevice =
                        await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) {
                          return DiscoveryPage();
                        },
                      ),
                    );

                    if (selectedDevice != null) {
                      print('Discovery -> selected ' + selectedDevice.address);
                    } else {
                      print('Discovery -> no device selected');
                    }
                  }),
            ),
            ListTile(
              title: RaisedButton(
                child: const Text('Try to Establish Communication'),
                onPressed: () async {
                  final BluetoothDevice selectedDevice =
                      await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) {
                        return SelectBondedDevicePage(checkAvailability: false);
                      },
                    ),
                  );

                  if (selectedDevice != null) {
                    print('Connect -> selected ' + selectedDevice.address);
                    _startChat(context, selectedDevice);
                  } else {
                    print('Connect -> no device selected');
                  }
                },
              ),
            ),
            ListTile(
              title: 
                  Column( children: <Widget>[ 
                          Text("Active Devices"),
                  (isDiscovering)// The error seemed to occur here
                    ? FittedBox( // but asks for some variable named visible
                      child: Container( // have to even learn the chat protocol if its of any use or try to Scavenge it
                       margin: new EdgeInsets.all(16.0),// The listTile is not dynamically Checked as future _bluetoothState.isenabled
                        child: CircularProgressIndicator(// is not allowing it to go in the discovery mode as i tried earlier
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                         ),
                          ),
                      )
                  : IconButton(
                      icon: Icon(Icons.replay),
                      onPressed: _restartDiscovery,
                      ),
                      ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (BuildContext context, index) {
                          BluetoothDiscoveryResult result = results[index];
                          return BluetoothDeviceListEntry(
                            device: result.device,
                            rssi: result.rssi,
                            onTap: () {
                              Navigator.of(context).pop(result.device);
                            },
                            onLongPress: () async {
                            try {
                            bool bonded = false;
                            if (result.device.isBonded) {
                            print('Unbonding from ${result.device.address}...');
                            await FlutterBluetoothSerial.instance
                                .removeDeviceBondWithAddress(result.device.address);
                            print('Unbonding from ${result.device.address} has succed');
                            } else {
                            print('Bonding with ${result.device.address}...');
                            bonded = await FlutterBluetoothSerial.instance
                            .bondDeviceAtAddress(result.device.address);
                            print(
                            'Bonding with ${result.device.address} has ${bonded ? 'succed' : 'failed'}.');
                            }
                            setState(() {
                            results[results.indexOf(result)] = BluetoothDiscoveryResult(
                              device: BluetoothDevice(
                              name: result.device.name ?? '',
                              address: result.device.address,
                              type: result.device.type,
                              bondState: bonded
                                  ? BluetoothBondState.bonded
                                  : BluetoothBondState.none,
                                ),
                              rssi: result.rssi);
                            });
                            } catch (ex) {
                            showDialog(
                            context: context,
                            builder: (BuildContext context) {
                            return AlertDialog(
                            title: const Text('Error occured while bonding'),
                            content: Text("${ex.toString()}"),
                            actions: <Widget>[
                            new FlatButton(
                            child: new Text("Close"),
                            onPressed: () {
                            Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                   );
                  }
                },
              );
            },
            ),
            ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  void _startChat(BuildContext context, BluetoothDevice server) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return ChatPage(server: server);
        },
      ),
    );
  }

}
