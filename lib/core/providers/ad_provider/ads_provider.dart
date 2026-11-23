// lib/providers/ad_provider/ad_provider.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_scanner_app/core/services/admob/admanager.dart';
import 'package:qr_scanner_app/core/utils/app_constants.dart';

class AdProvider extends ChangeNotifier {
  RewardedAd? _rewardedAd;
  static const AdRequest request = AdRequest();
  int _numRewardedLoadAttempts = 0;
  static int maxFailedLoadAttempts = 3;
  int _downloadButtonClickCount = 0;
  int _successfulDownloadCount = 0;
  int _appResumeCount = 0;
  InterstitialAd? _interstitialAd;
  int _numInterstitialLoadAttempts = 0;

  // Daily gallery scans limit state
  int _freeScansLeft = AppConstants.dailyGalleryScans;
  int get freeScansLeft => _freeScansLeft;

  // Daily generation limit state (QR + barcode combined)
  int _generationsLeft = AppConstants.dailyGenerationLimit;
  int get generationsLeft => _generationsLeft;
  int _generationRewardedAdsWatched = 0;
  int get generationRewardedAdsWatched => _generationRewardedAdsWatched;
  int get generationRewardedAdsRemaining =>
      AppConstants.rewardedAdsRequiredForGenerationBonus -
      _generationRewardedAdsWatched;

  // Rewarded Ad
  bool _loadedRewardedAd = false;
  bool get loadedRewardedAd => _loadedRewardedAd;
  set loadedRewardedAd(bool value) {
    _loadedRewardedAd = value;
    debugPrint('REWARDED AD LOADED: $value');
    notifyListeners();
  }

  // Interstitial Ad
  bool _loadedInterstitialAd = false;
  bool get loadedInterstitialAd => _loadedInterstitialAd;
  set loadedInterstitialAd(bool value) {
    _loadedInterstitialAd = value;
    debugPrint('INTERSTITIAL AD LOADED: $value');
    notifyListeners();
  }

  bool shouldShowAdOnSuccessfulDownload() {
    _successfulDownloadCount++;
    debugPrint('✅ Successful download count: $_successfulDownloadCount');
    if (_successfulDownloadCount >= 2) {
      _successfulDownloadCount = 0;
      return true;
    }
    return false;
  }

  // Single unified method — all placements call this
  // Returns true if ad was shown, false if not available
  bool tryShowAd({
    VoidCallback? onDismissed,
  }) {
    if (_interstitialAd == null || !_isInterstitialAvailable) {
      debugPrint('AD: Not available — skipping');
      onDismissed?.call(); // Always call so app flow continues
      return false;
    }

    showInterstitialAd(
      onAdShowedFullScreen: (_) {},
      onAdDismissedFullScreen: (_) {
        onDismissed?.call();
      },
      onAdFailedToShowFullScreen: (_, error) {
        onDismissed?.call();
      },
    );
    return true;
  }

  // Placement: every 5 download button clicks
  bool shouldShowAdOnDownloadClick() {
    _downloadButtonClickCount++;
    debugPrint('Download button click count: $_downloadButtonClickCount');
    if (_downloadButtonClickCount >= 5) {
      _downloadButtonClickCount = 0;
      return true;
    }
    return false;
  }

  // Placement: app resume
  bool shouldShowAdOnResume() {
    _appResumeCount++;
    debugPrint('App resume count: $_appResumeCount');
    return true;
  }

  Timer? _interstitialTimer;
  bool _isInterstitialAvailable = false;
  bool get isInterstitialAvailable => _isInterstitialAvailable;
  set isInterstitialAvailable(bool value) {
    _isInterstitialAvailable = value;
    debugPrint('INTERSTITIAL AD AVAILABLE: $value');
    notifyListeners();
  }

  int _counter = 0;

  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;
  bool get nativeAdIsLoaded => _nativeAdIsLoaded;

  AdProvider() {
    debugPrint('🟢 AdProvider created');
    initGalleryScansLimit();
    initGenerationLimit();
    _requestConsentAndInitialize();
  }

  void _requestConsentAndInitialize() {
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (await ConsentInformation.instance.isConsentFormAvailable()) {
          _loadConsentForm();
        } else {
          _initializeAds();
        }
      },
      (FormError error) => _initializeAds(),
    );
  }

  void _loadConsentForm() {
    ConsentForm.loadConsentForm(
      (ConsentForm consentForm) async {
        var status = await ConsentInformation.instance.getConsentStatus();
        if (status == ConsentStatus.required) {
          consentForm.show((FormError? formError) => _initializeAds());
        } else {
          _initializeAds();
        }
      },
      (FormError formError) => _initializeAds(),
    );
  }

  void _initializeAds() {
    // ADS DISABLED — AdMob account not verified.
    // Uncomment below when account is verified and ads are ready.
    /*
    MobileAds.instance.initialize().then((status) {
      debugPrint('📱 MobileAds initialized: ${status.adapterStatuses}');
      _createInterstitialAd();
      if (!_loadedRewardedAd) {
        _createRewardedAd();
      }
    });
    */
  }

  void loadAdsOnFirstUse() {
    if (!_loadedInterstitialAd) {
      _createInterstitialAd();
    }
    if (!_loadedRewardedAd) {
      _createRewardedAd();
    }
  }

  String get rewardedAdUnitId =>
      Platform.isAndroid ? AdManager.rewardIdAndroid : AdManager.rewardIdiOS;

  String get interstitialAdUnitId => Platform.isAndroid
      ? AdManager.interstitialIdAndroid
      : AdManager.interstitialIdiOS;

  String get nativeAdUnitId =>
      Platform.isAndroid ? AdManager.nativeIdAndroid : AdManager.nativeIdiOS;

  // Gallery Limit Persistence Logic
  Future<void> initGalleryScansLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('gallery_scan_date');

    if (lastDate != todayStr) {
      _freeScansLeft = AppConstants.dailyGalleryScans;
      await prefs.setString('gallery_scan_date', todayStr);
      await prefs.setInt('gallery_scans_left', AppConstants.dailyGalleryScans);
    } else {
      _freeScansLeft =
          prefs.getInt('gallery_scans_left') ?? AppConstants.dailyGalleryScans;
    }
    notifyListeners();
  }

  Future<void> initGenerationLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = prefs.getString('generation_date');

    if (lastDate != todayStr) {
      _generationsLeft = AppConstants.dailyGenerationLimit;
      _generationRewardedAdsWatched = 0;
      await prefs.setString('generation_date', todayStr);
      await prefs.setInt('generations_left', AppConstants.dailyGenerationLimit);
      await prefs.setInt('generation_rewarded_ads_watched', 0);
    } else {
      _generationsLeft =
          prefs.getInt('generations_left') ?? AppConstants.dailyGenerationLimit;
      _generationRewardedAdsWatched =
          prefs.getInt('generation_rewarded_ads_watched') ?? 0;
    }
    notifyListeners();
  }

  Future<bool> useGeneration() async {
    if (_generationsLeft <= 0) return false;
    _generationsLeft--;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('generations_left', _generationsLeft);
    notifyListeners();
    return true;
  }

  Future<void> addRewardedGenerations() async {
    _generationsLeft += AppConstants.rewardedGenerationBonus;
    _generationRewardedAdsWatched = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('generations_left', _generationsLeft);
    await prefs.setInt('generation_rewarded_ads_watched', 0);
    notifyListeners();
  }

  Future<void> recordGenerationRewardedAd() async {
    _generationRewardedAdsWatched++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'generation_rewarded_ads_watched',
      _generationRewardedAdsWatched,
    );
    if (_generationRewardedAdsWatched >=
        AppConstants.rewardedAdsRequiredForGenerationBonus) {
      await addRewardedGenerations();
    } else {
      notifyListeners();
    }
  }

  Future<void> useFreeScan() async {
    if (_freeScansLeft > 0) {
      _freeScansLeft--;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('gallery_scans_left', _freeScansLeft);
      notifyListeners();
    }
  }

  Future<void> addSingleScan() async {
    _freeScansLeft += 1; // Grant exactly 1 scan fallback
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gallery_scans_left', _freeScansLeft);
    notifyListeners();
  }

  Future<void> addRewardedScans() async {
    _freeScansLeft += AppConstants.rewardedGalleryScans;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('gallery_scans_left', _freeScansLeft);
    notifyListeners();
  }

  // REWARDED AD
  void _createRewardedAd() {
    debugPrint('REWARDED AD: Loading... (Attempt: $_numRewardedLoadAttempts)');
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: request,
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('REWARDED AD: LOADED SUCCESSFULLY!');
          _rewardedAd = ad;
          _numRewardedLoadAttempts = 0;
          loadedRewardedAd = true;
        },
        onAdFailedToLoad: (error) {
          debugPrint('REWARDED AD: FAILED TO LOAD → $error');
          loadedRewardedAd = false;
          _numRewardedLoadAttempts++;
          if (_numRewardedLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(const Duration(seconds: 3), _createRewardedAd);
          }
        },
      ),
    );
  }

  void showRewardedAd({
    required VoidCallback onUserEarnedReward,
    VoidCallback? onDismissed,
  }) {
    if (_rewardedAd == null) {
      debugPrint('REWARDED AD: NOT LOADED — Cannot show');
      _createRewardedAd(); // Proactively attempt reload
      onDismissed?.call();
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        loadedRewardedAd = false;
        _createRewardedAd();
        onDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        loadedRewardedAd = false;
        _createRewardedAd();
        onDismissed?.call();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        onUserEarnedReward();
      },
    );
    _rewardedAd = null;
  }

  // INTERSTITIAL AD
  void _createInterstitialAd() {
    debugPrint(
      'INTERSTITIAL AD: Loading... (Attempt: $_numInterstitialLoadAttempts)',
    );
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('INTERSTITIAL AD: LOADED SUCCESSFULLY!');
          _interstitialAd = ad;
          _numInterstitialLoadAttempts = 0;
          _interstitialAd!.setImmersiveMode(true);
          loadedInterstitialAd = true;
          isInterstitialAvailable = false;
          _startInterstitialTimer();
        },
        onAdFailedToLoad: (error) {
          debugPrint('INTERSTITIAL AD: FAILED TO LOAD → $error');
          loadedInterstitialAd = false;
          isInterstitialAvailable = false;
          _numInterstitialLoadAttempts++;
          if (_numInterstitialLoadAttempts < maxFailedLoadAttempts) {
            Future.delayed(const Duration(seconds: 3), _createInterstitialAd);
          }
        },
      ),
    );
  }

  void _startInterstitialTimer() {
    _interstitialTimer?.cancel();
    _counter++;
    debugPrint(
      'INTERSTITIAL TIMER: Started #$_counter (${AppConstants.interstitialAdShowingInterval}s)',
    );
    _interstitialTimer = Timer(
      const Duration(seconds: AppConstants.interstitialAdShowingInterval),
      () {
        debugPrint('INTERSTITIAL TIMER: AD NOW AVAILABLE! #$_counter');
        isInterstitialAvailable = true;
      },
    );
  }

  void showInterstitialAd({
    required Function(InterstitialAd) onAdShowedFullScreen,
    required Function(InterstitialAd) onAdDismissedFullScreen,
    required Function(InterstitialAd, dynamic) onAdFailedToShowFullScreen,
  }) {
    if (_interstitialAd == null) {
      debugPrint('INTERSTITIAL AD: NOT LOADED — Cannot show');
      return;
    }
    if (!_isInterstitialAvailable) {
      debugPrint('INTERSTITIAL AD: NOT AVAILABLE YET — Timer running');
      return;
    }

    debugPrint('INTERSTITIAL AD: SHOWING NOW!');
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('INTERSTITIAL AD: DISPLAYED ON SCREEN');
        onAdShowedFullScreen(ad);
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('INTERSTITIAL AD: DISMISSED BY USER');
        ad.dispose();
        _createInterstitialAd();
        onAdDismissedFullScreen(ad);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('INTERSTITIAL AD: FAILED TO SHOW → $error');
        ad.dispose();
        _createInterstitialAd();
        onAdFailedToShowFullScreen(ad, error);
      },
    );

    _interstitialAd!.show();
    isInterstitialAvailable = false;
    _interstitialAd = null;
  }

  // void _loadNativeAd() {
  //   debugPrint('Native Ad: Loading...');
  // 
  //   _nativeAd = NativeAd(
  //     adUnitId: nativeAdUnitId,
  //     factoryId: 'listTile',
  //     listener: NativeAdListener(
  //       onAdLoaded: (ad) {
  //         debugPrint('Native Ad loaded successfully!');
  //         _nativeAdIsLoaded = true;
  //         notifyListeners();
  //       },
  //       onAdFailedToLoad: (ad, error) {
  //         debugPrint('Native Ad failed to load: $error');
  //         ad.dispose();
  //         _nativeAdIsLoaded = false;
  //         notifyListeners();
  //       },
  //     ),
  //     request: const AdRequest(),
  //     customOptions: {'custom-option-1': 'custom-value-1'},
  //   );
  // 
  //   _nativeAd!.load();
  // }

  NativeAd? get nativeAd => _nativeAdIsLoaded ? _nativeAd : null;

  void loadNativeAd() {
    if (_nativeAdIsLoaded) return;

    _nativeAd = NativeAd(
      adUnitId: nativeAdUnitId,
      factoryId: 'listTile',
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          _nativeAdIsLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _nativeAdIsLoaded = false;
          notifyListeners();
        },
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    debugPrint('AdProvider: Disposing all ads...');
    _rewardedAd?.dispose();
    _interstitialAd?.dispose();
    _nativeAd?.dispose();
    _interstitialTimer?.cancel();
    super.dispose();
  }
}
