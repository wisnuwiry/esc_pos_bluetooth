/*
 * esc_pos_bluetooth
 * Created by Andrey Ushakov
 * 
 * Copyright (c) 2019-2020. All rights reserved.
 * See LICENSE for distribution and usage details.
 */

import 'dart:async';
import 'dart:io';

import 'package:esc_pos_bluetooth/esc_pos_bluetooth.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_basic/flutter_bluetooth_basic.dart';
import 'package:rxdart/rxdart.dart';

import './enums.dart';

/// Printer Bluetooth Manager
class PrinterBluetoothManager {
  final BluetoothManager _bluetoothManager = BluetoothManager.instance;
  StreamSubscription _isScanningSubscription;

  final BehaviorSubject<bool> _isScanning = BehaviorSubject.seeded(false);
  Stream<bool> get isScanningStream => _isScanning.stream;

  Stream<List<BluetoothDevice>> get scanResults =>
      _bluetoothManager.scanResults;

  void startScan(Duration timeout) async {
    try {
      await _bluetoothManager.startScan(timeout: timeout);
      await _isScanningSubscription?.cancel();

      _isScanningSubscription =
          _bluetoothManager.isScanning.listen((isScanningCurrent) {
        _isScanning.add(isScanningCurrent);
      }, onError: (Object err) {
        print('ERROR: when listen isScanning e: $err');
      });
    } catch (e) {
      print('ERROR: when listen isScanning ${e.toString()}');
    }
  }

  Future stopScan() async {
    try {
      await _bluetoothManager.stopScan();
    } catch (e) {
      print('ERROR: when stop scan ${e.toString()}');
    }
  }

  Future<bool> selectPrinter(BluetoothDevice printer) async {
    try {
      await _bluetoothManager.connect(printer);
      printer = printer;

      // bool takeUntil(BluetoothConnectionState state) =>
      //     state == BluetoothConnectionState.connected ||
      //     state == BluetoothConnectionState.stateOff;

      // final streamState = _bluetoothManager.state.takeWhile(takeUntil);

      // bool pendingResult = false;
      // await for (var item in streamState) {
      //   print('Item $item');
      //   if (item == BluetoothConnectionState.connected) {
      //     pendingResult = true;
      //   } else {
      //     pendingResult = false;
      //   }
      // }

      // return pendingResult;
      return true;
    } on PlatformException catch (e) {
      print(
          'ERROR: when select printer \ncode: ${e.code} \nmessage: ${e.message}');
      throw e;
    }
  }

  Future<PosPrintResult> writeBytes(
    List<int> bytes, {
    int chunkSizeBytes = 20,
    int queueSleepTimeMs = 20,
  }) async {
    Completer<PosPrintResult> completer = Completer();

    if (!(await _bluetoothManager.isConnected)) {
      return Future<PosPrintResult>.value(PosPrintResult.printerNotSelected);
    } else if (_isScanning.value) {
      return Future<PosPrintResult>.value(PosPrintResult.scanInProgress);
    }

    if (!(await _bluetoothManager.isConnected)) {
      final len = bytes.length;
      List<List<int>> chunks = [];
      for (var i = 0; i < len; i += chunkSizeBytes) {
        var end = (i + chunkSizeBytes < len) ? i + chunkSizeBytes : len;
        chunks.add(bytes.sublist(i, end));
      }

      for (var i = 0; i < chunks.length; i += 1) {
        await _bluetoothManager.writeData(chunks[i]);
        sleep(Duration(milliseconds: queueSleepTimeMs));
      }

      if (!completer.isCompleted) {
        completer = Completer();
        completer.complete(PosPrintResult.success);
      } else {
        completer.complete(PosPrintResult.success);
      }
    } else {
      final len = bytes.length;
      List<List<int>> chunks = [];
      for (var i = 0; i < len; i += chunkSizeBytes) {
        var end = (i + chunkSizeBytes < len) ? i + chunkSizeBytes : len;
        chunks.add(bytes.sublist(i, end));
      }

      for (var i = 0; i < chunks.length; i += 1) {
        await _bluetoothManager.writeData(chunks[i]);
        sleep(Duration(milliseconds: queueSleepTimeMs));
      }

      if (!completer.isCompleted) {
        completer = Completer();
        completer.complete(PosPrintResult.success);
      } else {
        completer.complete(PosPrintResult.success);
      }
    }

    return completer.future;
  }

  Future<PosPrintResult> printTicket(
    Ticket ticket, {
    int chunkSizeBytes = 20,
    int queueSleepTimeMs = 20,
  }) async {
    try {
      if (ticket == null || ticket.bytes.isEmpty) {
        return Future<PosPrintResult>.value(PosPrintResult.ticketEmpty);
      }
      return writeBytes(
        ticket.bytes,
        chunkSizeBytes: chunkSizeBytes,
        queueSleepTimeMs: queueSleepTimeMs,
      );
    } catch (e) {
      print('ERROR: when print ticker ${e.toString()}');
      return PosPrintResult.timeout;
    }
  }
}
