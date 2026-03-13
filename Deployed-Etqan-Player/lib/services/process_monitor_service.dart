import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// قائمة ببرامج التصوير الشائعة
class ScreenCaptureApps {
  static const List<String> windowsApps = [
    // Windows Native Tools
    'snippingtool.exe',
    'ScreenSketch.exe',
    'ScreenRecorder.exe',
    'GameBar.exe',
    'GameBarFTServer.exe',
    'XboxGameBar.exe',
    'XboxGipSvc.exe',
    'Win+G', // Xbox Game Bar shortcut
    // Popular Screen Recording Software
    'OBS64.exe',
    'obs32.exe',
    'obs.exe',
    'OBS Studio',
    'Bandicam.exe',
    'BandicamPortable.exe',
    'CamtasiaStudio.exe',
    'CamtasiaRecorder.exe',
    'Camtasia',
    'ShareX.exe',
    'ShareXPortable.exe',
    'Snagit.exe',
    'SnagitEditor.exe',
    'Snagit',
    'XSplit.exe',
    'XSplitBroadcaster.exe',
    'XSplitGamecaster.exe',
    'Fraps.exe',

    // Screenshot Tools
    'Greenshot.exe',
    'Lightshot.exe',
    'PicPick.exe',
    'FastStoneCapture.exe',
    'SnippingTool.exe',
    'Screenpresso.exe',
    'Monosnap.exe',
    'Flameshot.exe',

    // Video Conferencing (Screen Sharing)
    'Teams.exe',
    'Zoom.exe',
    'Discord.exe',
    'Skype.exe',
    'GoogleMeet.exe',
    'WebexMTA.exe',
    'BlueJeans.exe',
    'GoToMeeting.exe',
    'TeamViewer.exe',
    'AnyDesk.exe',
    'ChromeRemoteDesktop.exe',

    // Other Screen Capture Tools
    'ScreenToGif.exe',
    'LICEcap.exe',
    'GifCam.exe',
    'RecordIt.exe',
    'ScreenFlow.exe',
    'MovaviScreenRecorder.exe',
    'IcecreamScreenRecorder.exe',
    'FreeCam.exe',
    'ActivePresenter.exe',
    'Debut.exe',
    'FlashBack.exe',
    'MirillisAction.exe',
    'PlayClaw.exe',
    'ShadowPlay.exe', // NVIDIA
    'ReLive.exe', // AMD
  ];

  static const List<String> macApps = [
    // macOS Native Tools
    'Screenshot',
    'QuickTime Player',
    'QuickTime',
    'Grab',

    // Popular Screen Recording Software
    'OBS',
    'OBS Studio',
    'ScreenFlow',
    'Camtasia',
    'CamtasiaRecorder',
    'Snagit',
    'Screenpresso',
    'Monosnap',
    'CleanShot',
    'Kap',
    'RecordIt',
    'ScreenStudio',
    'Screenflick',
    'Screenium',
    'Screenium3',
    'Screenium4',
    'Screenium5',
    'ScreenRecorder',
    'MovaviScreenRecorder',
    'IcecreamScreenRecorder',
    'Loom',
    'CloudApp',
    'Droplr',

    // Video Conferencing (Screen Sharing)
    'Zoom',
    'Skype',
    'Teams',
    'GoogleMeet',
    'Webex',
    'BlueJeans',
    'GoToMeeting',
    'TeamViewer',
    'AnyDesk',
    'ChromeRemoteDesktop',

    // Other Tools
    'ScreenToGif',
    'Gifox',
    'GifBrewery',
    'Kap',
    'RecordIt',
  ];

  static const List<String> linuxApps = [
    // Linux Native Tools
    'gnome-screenshot',
    'ksnapshot',
    'scrot',
    'maim',
    'flameshot',
    'shutter',
    'spectacle',

    // Screen Recording
    'OBS',
    'OBS Studio',
    'SimpleScreenRecorder',
    'kazam',
    'vokoscreen',
    'peek',
    'byzanz',
    'recordmydesktop',
    'gtk-recordmydesktop',

    // Video Conferencing
    'Zoom',
    'Skype',
    'Teams',
    'GoogleMeet',
    'Webex',
    'TeamViewer',
    'AnyDesk',
  ];

  // iOS Screen Recording Apps (process names may vary)
  static const List<String> iosApps = [
    'Screen Recording', // iOS Native
    'DU Recorder',
    'TechSmith Capture',
    'Record it!',
    'RecordIt',
    'Screen Recorder',
    'AZ Screen Recorder',
    'Mobizen',
    'XRecorder',
    'Apowersoft',
    'AirShou',
    'Reflector',
    'AirPlay',
  ];

  // Android Screen Recording Apps
  static const List<String> androidApps = [
    'AZ Screen Recorder',
    'Mobizen Screen Recorder',
    'Mobizen',
    'DU Recorder',
    'Google Play Games',
    'XRecorder',
    'Screen Recorder',
    'Apowersoft Screen Recorder',
    'Apowersoft',
    'Screen Recorder - No Ads',
    'Adv Screen Recorder',
    'MNML Screen Recorder',
    'ScreenCam Screen Recorder',
    'RecMe',
    'Screen Recorder Pro',
    'SCR Screen Recorder',
    'Screen Recorder - Video Recorder',
    'Screen Recorder HD',
    'Screen Recorder - Game Recorder',
  ];
}

/// خدمة مراقبة برامج التصوير والتسجيل
class ProcessMonitorService {
  static final ProcessMonitorService _instance =
      ProcessMonitorService._internal();

  factory ProcessMonitorService() => _instance;
  ProcessMonitorService._internal();

  Timer? _monitoringTimer;
  bool _isMonitoring = false;
  final Set<String> _detectedApps = {};

  Function(bool, Set<String>)? onAppsDetected;

  /// بدء مراقبة برامج التصوير
  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    // debugPrint('🔍 Starting process monitoring...');

    _monitoringTimer = Timer.periodic(interval, (timer) {
      _checkRunningProcesses();
    });

    // فحص فوري
    _checkRunningProcesses();
  }

  /// إيقاف المراقبة
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    _detectedApps.clear();
    // debugPrint('🛑 Process monitoring stopped');
  }

  /// فحص العمليات الجارية
  Future<void> _checkRunningProcesses() async {
    try {
      Set<String> detected = {};

      List<String> targetApps = [];
      if (Platform.isWindows) {
        targetApps = ScreenCaptureApps.windowsApps;
      } else if (Platform.isMacOS) {
        targetApps = ScreenCaptureApps.macApps;
      } else if (Platform.isLinux) {
        targetApps = ScreenCaptureApps.linuxApps;
      } else if (Platform.isIOS) {
        targetApps = ScreenCaptureApps.iosApps;
      } else if (Platform.isAndroid) {
        targetApps = ScreenCaptureApps.androidApps;
      }

      // التحقق من التركيز (Focus) - النافذة النشطة
      String? activeProcessName = await _getActiveWindowProcessName();
      
      if (activeProcessName != null && activeProcessName.isNotEmpty) {
        // التحقق من أن البرنامج النشط هو أحد برامج التصوير
        // في Windows، ProcessName يعطي الاسم بدون .exe
        String processNameLower = activeProcessName.toLowerCase();
        for (String app in targetApps) {
          String appLower = app.toLowerCase();
          // إزالة .exe من اسم التطبيق للمقارنة
          if (appLower.endsWith('.exe')) {
            appLower = appLower.substring(0, appLower.length - 4);
          }
          // المقارنة
          if (processNameLower == appLower || 
              processNameLower.contains(appLower) ||
              appLower.contains(processNameLower)) {
            detected.add(app);
            if (!_detectedApps.contains(app)) {
              // debugPrint('⚠️ Screen capture app focused: $app (Process: $activeProcessName)');
            }
          }
        }
      }

      // تحديث القائمة المكتشفة
      bool hasNewDetection = detected.isNotEmpty && _detectedApps.isEmpty;
      bool hasRemovedDetection = detected.isEmpty && _detectedApps.isNotEmpty;
      bool stateChanged = hasNewDetection || hasRemovedDetection;

      // تحديث القائمة المكتشفة
      Set<String> previousApps = Set.from(_detectedApps);
      _detectedApps.clear();
      _detectedApps.addAll(detected);

      // إشعار عند اكتشاف أو إزالة برامج
      if (stateChanged) {
        if (hasNewDetection) {
          debugPrint('🚨 Screen capture app focused: ${detected.join(", ")}');
        } else if (hasRemovedDetection) {
          debugPrint(
            '✅ Screen capture app lost focus: ${previousApps.join(", ")}',
          );
          debugPrint('🟢 Screen capture app is no longer active');
        }
        onAppsDetected?.call(detected.isNotEmpty, detected);
      }
    } catch (e) {
      // debugPrint('❌ Error checking processes: $e');
    }
  }

  /// الحصول على اسم العملية للنافذة النشطة (Active Window)
  Future<String?> _getActiveWindowProcessName() async {
    try {
      if (Platform.isWindows) {
        // استخدام PowerShell للحصول على اسم العملية للنافذة النشطة
        final powershellScript = r'''
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    public static extern int GetWindowThreadProcessId(IntPtr hWnd, out int ProcessId);
    public static string GetActiveProcessName() {
        IntPtr hwnd = GetForegroundWindow();
        int pid;
        GetWindowThreadProcessId(hwnd, out pid);
        try {
            return Process.GetProcessById(pid).ProcessName;
        } catch { return ""; }
    }
}
"@
[Win32]::GetActiveProcessName()
''';

        ProcessResult result = await Process.run(
          'powershell',
          ['-Command', powershellScript],
        );

        if (result.exitCode == 0) {
          String processName = result.stdout.toString().trim();
          if (processName.isNotEmpty && !processName.contains('Exception')) {
            return processName;
          }
        }
      } else if (Platform.isMacOS) {
        // macOS: استخدام AppleScript للحصول على النافذة النشطة
        ProcessResult result = await Process.run(
          'osascript',
          ['-e', 'tell application "System Events" to get name of first process whose frontmost is true'],
        );
        if (result.exitCode == 0) {
          return result.stdout.toString().trim();
        }
      } else if (Platform.isLinux) {
        // Linux: استخدام xdotool للحصول على النافذة النشطة
        try {
          ProcessResult result = await Process.run(
            'xdotool',
            ['getactivewindow', 'getwindowpid'],
          );
          if (result.exitCode == 0) {
            String pid = result.stdout.toString().trim();
            ProcessResult psResult = await Process.run('ps', ['-p', pid, '-o', 'comm=',]);
            if (psResult.exitCode == 0) {
              return psResult.stdout.toString().trim();
            }
          }
        } catch (e) {
          debugPrint('⚠️ xdotool not available: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error getting active window process: $e');
    }
    return null;
  }


  /// التحقق من وجود برامج تصوير نشطة
  bool get hasActiveCaptureApps => _detectedApps.isNotEmpty;

  /// الحصول على قائمة البرامج المكتشفة
  Set<String> get detectedApps => Set.from(_detectedApps);

  /// تنظيف الموارد
  void dispose() {
    stopMonitoring();
  }
}
