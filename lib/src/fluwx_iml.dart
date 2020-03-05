/*
 * Copyright (C) 2018 The OpenFlutter Organization
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../fluwx.dart';
import 'models/wechat_auth_by_qr_code.dart';
import 'models/wechat_response.dart';
import 'models/wechat_share_models.dart';
import 'utils/utils.dart';
import 'wechat_type.dart';

final MethodChannel _channel = const MethodChannel('com.jarvanmo/fluwx')
  ..setMethodCallHandler(Fluwx._handler);

typedef FluwxCallBack<T> = void Function(T data);

class Fluwx {
  static final Fluwx _singleton = new Fluwx._internal();
  Map<String, List<FluwxCallBack>> _queueMap = {};
  factory Fluwx() {
    return _singleton;
  }

  Fluwx._internal();

  static Future<dynamic> _handler(MethodCall methodCall) {
    if ("onShareResponse" == methodCall.method) {
      Fluwx.handleResponse(
          methodCall.method, WeChatShareResponse.fromMap(methodCall.arguments));
    } else if ("onAuthResponse" == methodCall.method) {
      Fluwx.handleResponse(
          methodCall.method, WeChatAuthResponse.fromMap(methodCall.arguments));
    } else if ("onLaunchMiniProgramResponse" == methodCall.method) {
      Fluwx.handleResponse(methodCall.method,
          WeChatLaunchMiniProgramResponse.fromMap(methodCall.arguments));
    } else if ("onPayResponse" == methodCall.method) {
      Fluwx.handleResponse(methodCall.method,
          WeChatPaymentResponse.fromMap(methodCall.arguments));
    } else if ("onSubscribeMsgResp" == methodCall.method) {
      Fluwx.handleResponse(methodCall.method,
          WeChatSubscribeMsgResp.fromMap(methodCall.arguments));
    } else if ("onAuthByQRCodeFinished" == methodCall.method) {
      int errCode = methodCall.arguments["errCode"];
      Fluwx.handleResponse(
          methodCall.method,
          AuthByQRCodeResult(
              methodCall.arguments["authCode"],
              _authByQRCodeErrorCodes[errCode] ??
                  AuthByQRCodeErrorCode.UNKNOWN));
    } else if ("onAuthGotQRCode" == methodCall.method) {
      Fluwx.handleResponse(methodCall.method, Map.from(methodCall.arguments));
    } else if ("onQRCodeScanned" == methodCall.method) {
      Fluwx.handleResponse(methodCall.method, true);
    } else if ("onAutoDeductResponse" == methodCall.method) {
      Fluwx.handleResponse(methodCall.method,
          WeChatAutoDeductResponse.fromMap(methodCall.arguments));
    }

    return Future.value(true);
  }

  ///[appId] is not necessary.
  ///if [doOnIOS] is true ,fluwx will register WXApi on iOS.
  ///if [doOnAndroid] is true, fluwx will register WXApi on Android.
  /// [universalLink] is required if you want to register on iOS.
  @Deprecated("repleace with registerWxApi")
  static Future register(
      {String appId,
      bool doOnIOS: true,
      bool doOnAndroid: true,
      String universalLink}) async {
    return await _channel.invokeMethod("registerApp", {
      "appId": appId,
      "iOS": doOnIOS,
      "android": doOnAndroid,
      "universalLink": universalLink
    });
  }

  ///[appId] is not necessary.
  ///if [doOnIOS] is true ,fluwx will register WXApi on iOS.
  ///if [doOnAndroid] is true, fluwx will register WXApi on Android.
  /// [universalLink] is required if you want to register on iOS.
  static Future registerWxApi(
      {String appId,
      bool doOnIOS: true,
      bool doOnAndroid: true,
      String universalLink}) async {
    if (doOnIOS && Platform.isIOS) {
      if (universalLink.trim().isEmpty || !universalLink.startsWith("https")) {
        throw ArgumentError.value(universalLink,
            "your universal link is illegal, see https://developers.weixin.qq.com/doc/oplatform/Mobile_App/Access_Guide/iOS.html for detail");
      }
    }

    return await _channel.invokeMethod("registerApp", {
      "appId": appId,
      "iOS": doOnIOS,
      "android": doOnAndroid,
      "universalLink": universalLink
    });
  }

  ///we don't need the response any longer if params are true.
  @Deprecated("use closeFluwxStreams instead")
  void dispose({
    shareResponse: true,
    authResponse: true,
    paymentResponse: true,
    launchMiniProgramResponse: true,
    onAuthByQRCodeFinished: true,
    onAuthGotQRCode: true,
    onQRCodeScanned: true,
  }) {}

  ///we don't need the response any longer if params are true.
  static void closeFluwxStreams({
    shareResponse: true,
    authResponse: true,
    paymentResponse: true,
    launchMiniProgramResponse: true,
    onAuthByQRCodeFinished: true,
    onAuthGotQRCode: true,
    onQRCodeScanned: true,
  }) {}

//  static Future unregisterApp(RegisterModel model) async {
//    return await _channel.invokeMethod("unregisterApp", model.toMap());
//  }

  ///the [WeChatShareModel] can not be null
  ///see [WeChatShareWebPageModel]
  /// [WeChatShareTextModel]
  ///[WeChatShareVideoModel]
  ///[WeChatShareMusicModel]
  ///[WeChatShareImageModel]
  @Deprecated("use shareToWeChat instead")
  static Future share(WeChatShareModel model,
      {@required FluwxCallBack<WeChatShareResponse> callback}) async {
    if (_shareModelMethodMapper.containsKey(model.runtimeType)) {
      _addCallback("onShareResponse", callback);
      return await _channel.invokeMethod(
          _shareModelMethodMapper[model.runtimeType], model.toMap());
    } else {
      return Future.error("no method mapper found[${model.runtimeType}]");
    }
  }

  ///the [WeChatShareModel] can not be null
  ///see [WeChatShareWebPageModel]
  /// [WeChatShareTextModel]
  ///[WeChatShareVideoModel]
  ///[WeChatShareMusicModel]
  ///[WeChatShareImageModel]
  static Future shareToWeChat(WeChatShareModel model,
      {@required FluwxCallBack<WeChatShareResponse> callback}) async {
    if (_shareModelMethodMapper.containsKey(model.runtimeType)) {
      _addCallback("onShareResponse", callback);
      return await _channel.invokeMethod(
          _shareModelMethodMapper[model.runtimeType], model.toMap());
    } else {
      return Future.error("no method mapper found[${model.runtimeType}]");
    }
  }

  /// The WeChat-Login is under Auth-2.0
  /// This method login with native WeChat app.
  /// For users without WeChat app, please use [authByQRCode] instead
  /// This method only supports getting AuthCode,this is first step to login with WeChat
  /// Once AuthCode got, you need to request Access_Token
  /// For more information please visit：
  /// * https://open.weixin.qq.com/cgi-bin/showdocument?action=dir_list&t=resource/res_list&verify=1&id=open1419317851&token=
  @Deprecated("use sendWeChatAuth instead")
  static Future sendAuth(
      {String openId,
      @required String scope,
      String state,
      @required FluwxCallBack<WeChatAuthResponse> callback}) async {
    // "scope": scope, "state": state, "openId": openId

    assert(scope != null && scope.trim().isNotEmpty);
    _addCallback("onAuthResponse", callback);

    return await _channel.invokeMethod(
        "sendAuth", {"scope": scope, "state": state, "openId": openId});
  }

  /// Sometimes WeChat  is not installed on users's devices.However we can
  /// request a QRCode so that we can get AuthCode by scanning the QRCode
  /// All required params must not be null or empty
  /// [schemeData] only works on iOS
  /// see * https://open.weixin.qq.com/cgi-bin/showdocument?action=dir_list&t=resource/res_list&verify=1&id=215238808828h4XN&token=&lang=zh_CN
  @Deprecated("use authWeChatByQRCode instead")
  static Future authByQRCode({
    @required String appId,
    @required String scope,
    @required String nonceStr,
    @required String timeStamp,
    @required String signature,
    String schemeData,
    @required FluwxCallBack<AuthByQRCodeResult> callback,
  }) async {
    assert(appId != null && appId.isNotEmpty);
    assert(scope != null && scope.isNotEmpty);
    assert(nonceStr != null && nonceStr.isNotEmpty);
    assert(timeStamp != null && timeStamp.isNotEmpty);
    assert(signature != null && signature.isNotEmpty);
    _addCallback("onAuthByQRCodeFinished", callback);
    return await _channel.invokeMethod("authByQRCode", {
      "appId": appId,
      "scope": scope,
      "nonceStr": nonceStr,
      "timeStamp": timeStamp,
      "signature": signature,
      "schemeData": schemeData
    });
  }

  /// Sometimes WeChat  is not installed on users's devices.However we can
  /// request a QRCode so that we can get AuthCode by scanning the QRCode
  /// All required params must not be null or empty
  /// [schemeData] only works on iOS
  /// see * https://open.weixin.qq.com/cgi-bin/showdocument?action=dir_list&t=resource/res_list&verify=1&id=215238808828h4XN&token=&lang=zh_CN
  static Future authWeChatByQRCode({
    @required String appId,
    @required String scope,
    @required String nonceStr,
    @required String timeStamp,
    @required String signature,
    String schemeData,
    @required FluwxCallBack<AuthByQRCodeResult> callback,
  }) async {
    assert(appId != null && appId.isNotEmpty);
    assert(scope != null && scope.isNotEmpty);
    assert(nonceStr != null && nonceStr.isNotEmpty);
    assert(timeStamp != null && timeStamp.isNotEmpty);
    assert(signature != null && signature.isNotEmpty);
    _addCallback("onAuthByQRCodeFinished", callback);

    return await _channel.invokeMethod("authByQRCode", {
      "appId": appId,
      "scope": scope,
      "nonceStr": nonceStr,
      "timeStamp": timeStamp,
      "signature": signature,
      "schemeData": schemeData
    });
  }

  /// stop auth
  @Deprecated("use stopWeChatAuthByQRCode instead")
  static Future stopAuthByQRCode() async {
    return await _channel.invokeMethod("stopAuthByQRCode");
  }

  /// stop auth
  static Future stopWeChatAuthByQRCode() async {
    return await _channel.invokeMethod("stopAuthByQRCode");
  }

  /// open mini-program
  /// see [WXMiniProgramType]
  @Deprecated("use launchWeChatMiniProgram instead")
  static Future launchMiniProgram({
    @required String username,
    String path,
    WXMiniProgramType miniProgramType = WXMiniProgramType.RELEASE,
    @required FluwxCallBack<WeChatLaunchMiniProgramResponse> callback,
  }) async {
    assert(username != null && username.trim().isNotEmpty);
    _addCallback("onLaunchMiniProgramResponse", callback);
    return await _channel.invokeMethod("launchMiniProgram", {
      "userName": username,
      "path": path,
      "miniProgramType": miniProgramTypeToInt(miniProgramType)
    });
  }

  /// open mini-program
  /// see [WXMiniProgramType]
  static Future launchWeChatMiniProgram({
    @required String username,
    String path,
    WXMiniProgramType miniProgramType = WXMiniProgramType.RELEASE,
    @required FluwxCallBack<WeChatLaunchMiniProgramResponse> callback,
  }) async {
    assert(username != null && username.trim().isNotEmpty);
    _addCallback("onLaunchMiniProgramResponse", callback);

    return await _channel.invokeMethod("launchMiniProgram", {
      "userName": username,
      "path": path,
      "miniProgramType": miniProgramTypeToInt(miniProgramType)
    });
  }

  /// true if WeChat is installed,otherwise false.
  /// However,the following key-value must be added into your info.plist since iOS 9:
  /// <key>LSApplicationQueriesSchemes</key>
  ///<array>
  ///<string>weixin</string>
  ///</array>
  ///<key>NSAppTransportSecurity</key>
  ///<dict>
  ///<key>NSAllowsArbitraryLoads</key>
  ///<true/>
  ///</dict>
  ///
  static Future isWeChatInstalled() async {
    return await _channel.invokeMethod("isWeChatInstalled");
  }

  /// params are from server
  @Deprecated("use payWithWeChat instead")
  static Future pay({
    @required String appId,
    @required String partnerId,
    @required String prepayId,
    @required String packageValue,
    @required String nonceStr,
    @required int timeStamp,
    @required String sign,
    String signType,
    String extData,
    @required FluwxCallBack<WeChatPaymentResponse> callback,
  }) async {
    _addCallback("onPayResponse", callback);
    return await _channel.invokeMethod("payWithFluwx", {
      "appId": appId,
      "partnerId": partnerId,
      "prepayId": prepayId,
      "packageValue": packageValue,
      "nonceStr": nonceStr,
      "timeStamp": timeStamp,
      "sign": sign,
      "signType": signType,
      "extData": extData,
    });
  }

  /// params are from server
  static Future payWithWeChat({
    @required String appId,
    @required String partnerId,
    @required String prepayId,
    @required String packageValue,
    @required String nonceStr,
    @required int timeStamp,
    @required String sign,
    String signType,
    String extData,
    @required FluwxCallBack<WeChatPaymentResponse> callback,
  }) async {
    _addCallback("onPayResponse", callback);
    return await _channel.invokeMethod("payWithFluwx", {
      "appId": appId,
      "partnerId": partnerId,
      "prepayId": prepayId,
      "packageValue": packageValue,
      "nonceStr": nonceStr,
      "timeStamp": timeStamp,
      "sign": sign,
      "signType": signType,
      "extData": extData,
    });
  }

  /// subscribe message
  @Deprecated("use subscribeWeChatMsg instead")
  static Future subscribeMsg({
    @required String appId,
    @required int scene,
    @required String templateId,
    String reserved,
    @required FluwxCallBack<WeChatSubscribeMsgResp> callback,
  }) async {
    _addCallback("onSubscribeMsgResp", callback);
    return await _channel.invokeMethod(
      "subscribeMsg",
      {
        "appId": appId,
        "scene": scene,
        "templateId": templateId,
        "reserved": reserved,
      },
    );
  }

  /// subscribe message
  static Future subscribeWeChatMsg({
    @required String appId,
    @required int scene,
    @required String templateId,
    String reserved,
    @required FluwxCallBack<WeChatSubscribeMsgResp> callback,
  }) async {
    _addCallback("onSubscribeMsgResp", callback);

    return await _channel.invokeMethod(
      "subscribeMsg",
      {
        "appId": appId,
        "scene": scene,
        "templateId": templateId,
        "reserved": reserved,
      },
    );
  }

  /// please read official docs.
  @Deprecated("use autoDeDuctWeChat instead")
  static Future autoDeDuct(
      {@required String appId,
      @required String mchId,
      @required String planId,
      @required String contractCode,
      @required String requestSerial,
      @required String contractDisplayAccount,
      @required String notifyUrl,
      @required String version,
      @required String sign,
      @required String timestamp,
      String returnApp = '3',
      int businessType = 12}) async {
    return await _channel.invokeMethod("autoDeduct", {
      'appid': appId,
      'mch_id': mchId,
      'plan_id': planId,
      'contract_code': contractCode,
      'request_serial': requestSerial,
      'contract_display_account': contractDisplayAccount,
      'notify_url': notifyUrl,
      'version': version,
      'sign': sign,
      'timestamp': timestamp,
      'return_app': returnApp,
      "businessType": businessType
    });
  }

  /// please read official docs.
  static Future autoDeDuctWeChat(
      {@required String appId,
      @required String mchId,
      @required String planId,
      @required String contractCode,
      @required String requestSerial,
      @required String contractDisplayAccount,
      @required String notifyUrl,
      @required String version,
      @required String sign,
      @required String timestamp,
      String returnApp = '3',
      int businessType = 12}) async {
    return await _channel.invokeMethod("autoDeduct", {
      'appid': appId,
      'mch_id': mchId,
      'plan_id': planId,
      'contract_code': contractCode,
      'request_serial': requestSerial,
      'contract_display_account': contractDisplayAccount,
      'notify_url': notifyUrl,
      'version': version,
      'sign': sign,
      'timestamp': timestamp,
      'return_app': returnApp,
      "businessType": businessType
    });
  }

  static Future<bool> openWeChatApp() async {
    return await _channel.invokeMethod("openWXApp");
  }

  static Map<Type, String> _shareModelMethodMapper = {
    WeChatShareTextModel: "shareText",
    WeChatShareImageModel: "shareImage",
    WeChatShareMusicModel: "shareMusic",
    WeChatShareVideoModel: "shareVideo",
    WeChatShareWebPageModel: "shareWebPage",
    WeChatShareMiniProgramModel: "shareMiniProgram",
    WeChatShareFileModel: "shareFile",
  };

  static Map<int, AuthByQRCodeErrorCode> _authByQRCodeErrorCodes = {
    0: AuthByQRCodeErrorCode.OK,
    -1: AuthByQRCodeErrorCode.NORMAL_ERR,
    -2: AuthByQRCodeErrorCode.NETWORK_ERR,
    -3: AuthByQRCodeErrorCode.JSON_DECODE_ERR,
    -4: AuthByQRCodeErrorCode.CANCEL,
    -5: AuthByQRCodeErrorCode.AUTH_STOPPED
  };

  static Future sendWeChatAuth(
      {String openId,
      @required String scope,
      String state,
      @required FluwxCallBack callback}) async {
    // "scope": scope, "state": state, "openId": openId
    assert(scope != null && scope.trim().isNotEmpty);
    _addCallback("onAuthResponse", callback);
    return await _channel.invokeMethod(
        "sendAuth", {"scope": scope, "state": state, "openId": openId});
  }

  static void _executeCallback<T>(String method, T data) {
    List<FluwxCallBack> queuedList = Fluwx()._queueMap[method];
    if (queuedList != null) {
      for (int i = queuedList.length - 1; i >= 0; i--) {
        queuedList[i](data);
      }
      queuedList.clear();
    }
  }

  static void _addCallback(String method, FluwxCallBack callback) {
    List<FluwxCallBack> queuedList = Fluwx()._queueMap[method];
    if (queuedList == null) {
      queuedList = [];
      Fluwx()._queueMap[method] = queuedList;
    }
    queuedList.add(callback);
  }

  static void handleResponse<T>(String methodName, T data) {
    _executeCallback(methodName, data);
  }
}
