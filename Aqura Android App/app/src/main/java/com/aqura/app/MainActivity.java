package com.aqura.app;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.view.Gravity;
import android.view.View;
import android.webkit.GeolocationPermissions;
import android.webkit.CookieManager;
import android.webkit.PermissionRequest;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.JavascriptInterface;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.TextView;

import androidx.activity.OnBackPressedCallback;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.annotation.NonNull;
import androidx.activity.ComponentActivity;
import androidx.core.content.ContextCompat;
import androidx.webkit.WebSettingsCompat;
import androidx.webkit.WebViewFeature;

import com.google.firebase.messaging.FirebaseMessaging;

import org.json.JSONObject;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;

public final class MainActivity extends ComponentActivity {
    private WebView webView;
    private ProgressBar progress;
    private View errorView;
    private ValueCallback<Uri[]> fileCallback;
    private PermissionRequest webPermissionRequest;
    private GeolocationPermissions.Callback geoCallback;
    private String geoOrigin;
    private boolean nativeTokenRequested;
    private final String trustedHost = URI.create(BuildConfig.AQURA_URL).getHost();

    private final ActivityResultLauncher<Intent> filePicker = registerForActivityResult(
            new ActivityResultContracts.StartActivityForResult(), result -> {
                Uri[] uris = null;
                if (result.getResultCode() == Activity.RESULT_OK && result.getData() != null) {
                    Intent data = result.getData();
                    if (data.getClipData() != null) {
                        uris = new Uri[data.getClipData().getItemCount()];
                        for (int i = 0; i < uris.length; i++) uris[i] = data.getClipData().getItemAt(i).getUri();
                    } else if (data.getData() != null) {
                        uris = new Uri[]{data.getData()};
                    }
                }
                if (fileCallback != null) fileCallback.onReceiveValue(uris);
                fileCallback = null;
            });

    private final ActivityResultLauncher<String[]> permissionLauncher = registerForActivityResult(
            new ActivityResultContracts.RequestMultiplePermissions(), result -> {
                if (webPermissionRequest != null) {
                    List<String> granted = new ArrayList<>();
                    for (String resource : webPermissionRequest.getResources()) {
                        if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(resource) &&
                                Boolean.TRUE.equals(result.get(Manifest.permission.CAMERA))) granted.add(resource);
                        if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(resource) &&
                                Boolean.TRUE.equals(result.get(Manifest.permission.RECORD_AUDIO))) granted.add(resource);
                    }
                    webPermissionRequest.grant(granted.toArray(new String[0]));
                    webPermissionRequest = null;
                }
                if (geoCallback != null) {
                    boolean allowed = Boolean.TRUE.equals(result.get(Manifest.permission.ACCESS_FINE_LOCATION));
                    geoCallback.invoke(geoOrigin, allowed, false);
                    geoCallback = null;
                }
                if (nativeTokenRequested) {
                    nativeTokenRequested = false;
                    if (Boolean.TRUE.equals(result.get(Manifest.permission.POST_NOTIFICATIONS))) {
                        deliverFcmToken();
                    } else {
                        dispatchPushToken(null, "denied");
                    }
                }
            });

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        buildUi();
        configureWebView();
        handleIntent(getIntent());
        getOnBackPressedDispatcher().addCallback(this, new OnBackPressedCallback(true) {
            @Override public void handleOnBackPressed() {
                if (webView.canGoBack()) webView.goBack(); else finish();
            }
        });
    }

    private void buildUi() {
        FrameLayout root = new FrameLayout(this);
        webView = new WebView(this);
        root.addView(webView, new FrameLayout.LayoutParams(-1, -1));

        progress = new ProgressBar(this);
        FrameLayout.LayoutParams progressParams = new FrameLayout.LayoutParams(64, 64, Gravity.CENTER);
        root.addView(progress, progressParams);

        LinearLayout error = new LinearLayout(this);
        error.setOrientation(LinearLayout.VERTICAL);
        error.setGravity(Gravity.CENTER);
        error.setPadding(48, 48, 48, 48);
        error.setBackgroundColor(Color.WHITE);
        TextView title = new TextView(this);
        title.setText(R.string.offline_title);
        title.setTextSize(22);
        title.setTextColor(Color.rgb(31, 41, 55));
        TextView message = new TextView(this);
        message.setText(R.string.offline_message);
        message.setGravity(Gravity.CENTER);
        message.setPadding(0, 20, 0, 28);
        Button retry = new Button(this);
        retry.setText(R.string.retry);
        retry.setOnClickListener(v -> { errorView.setVisibility(View.GONE); webView.reload(); });
        error.addView(title);
        error.addView(message);
        error.addView(retry);
        errorView = error;
        errorView.setVisibility(View.GONE);
        root.addView(errorView, new FrameLayout.LayoutParams(-1, -1));
        setContentView(root);
    }

    @SuppressLint("SetJavaScriptEnabled")
    private void configureWebView() {
        WebSettings settings = webView.getSettings();
        webView.addJavascriptInterface(new AndroidBridge(), "AquraAndroid");
        CookieManager.getInstance().setAcceptCookie(true);
        CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true);
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        settings.setMediaPlaybackRequiresUserGesture(false);
        settings.setGeolocationEnabled(true);
        settings.setUserAgentString(settings.getUserAgentString() + " AquraAndroid/1.0");
        if (WebViewFeature.isFeatureSupported(WebViewFeature.ALGORITHMIC_DARKENING)) {
            WebSettingsCompat.setAlgorithmicDarkeningAllowed(settings, false);
        }
        WebView.setWebContentsDebuggingEnabled(BuildConfig.DEBUG);

        webView.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                return route(request.getUrl());
            }
            @Override public void onPageFinished(WebView view, String url) {
                progress.setVisibility(View.GONE);
            }
            @Override public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
                if (request.isForMainFrame()) {
                    progress.setVisibility(View.GONE);
                    errorView.setVisibility(View.VISIBLE);
                }
            }
        });

        webView.setWebChromeClient(new WebChromeClient() {
            @Override public void onProgressChanged(WebView view, int value) {
                progress.setVisibility(value < 100 ? View.VISIBLE : View.GONE);
            }
            @Override public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback, FileChooserParams params) {
                if (fileCallback != null) fileCallback.onReceiveValue(null);
                fileCallback = callback;
                try { filePicker.launch(params.createIntent()); }
                catch (ActivityNotFoundException e) { fileCallback.onReceiveValue(null); fileCallback = null; }
                return true;
            }
            @Override public void onPermissionRequest(PermissionRequest request) {
                runOnUiThread(() -> requestWebPermissions(request));
            }
            @Override public void onGeolocationPermissionsShowPrompt(String origin, GeolocationPermissions.Callback callback) {
                if (!isTrusted(Uri.parse(origin))) { callback.invoke(origin, false, false); return; }
                if (ContextCompat.checkSelfPermission(MainActivity.this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                    callback.invoke(origin, true, false);
                } else {
                    geoOrigin = origin;
                    geoCallback = callback;
                    permissionLauncher.launch(new String[]{Manifest.permission.ACCESS_FINE_LOCATION});
                }
            }
        });

        webView.setDownloadListener((url, userAgent, disposition, mimeType, length) -> openExternal(Uri.parse(url)));
    }

    private void requestWebPermissions(PermissionRequest request) {
        if (!isTrusted(request.getOrigin())) { request.deny(); return; }
        List<String> permissions = new ArrayList<>();
        for (String resource : request.getResources()) {
            if (PermissionRequest.RESOURCE_VIDEO_CAPTURE.equals(resource)) permissions.add(Manifest.permission.CAMERA);
            if (PermissionRequest.RESOURCE_AUDIO_CAPTURE.equals(resource)) permissions.add(Manifest.permission.RECORD_AUDIO);
        }
        if (permissions.isEmpty()) { request.deny(); return; }
        webPermissionRequest = request;
        permissionLauncher.launch(permissions.toArray(new String[0]));
    }

    private boolean route(Uri uri) {
        String scheme = uri.getScheme();
        if ("http".equals(scheme) || "https".equals(scheme)) {
            if (isTrusted(uri)) return false;
            openExternal(uri);
            return true;
        }
        openExternal(uri);
        return true;
    }

    private boolean isTrusted(Uri uri) {
        return "https".equalsIgnoreCase(uri.getScheme()) && trustedHost.equalsIgnoreCase(uri.getHost());
    }

    private final class AndroidBridge {
        @JavascriptInterface public boolean isNativeApp() { return true; }

        @JavascriptInterface public void requestPushToken() {
            runOnUiThread(() -> {
                if (android.os.Build.VERSION.SDK_INT >= 33 &&
                        ContextCompat.checkSelfPermission(MainActivity.this, Manifest.permission.POST_NOTIFICATIONS)
                                != PackageManager.PERMISSION_GRANTED) {
                    nativeTokenRequested = true;
                    permissionLauncher.launch(new String[]{Manifest.permission.POST_NOTIFICATIONS});
                } else {
                    deliverFcmToken();
                }
            });
        }
    }

    private void deliverFcmToken() {
        FirebaseMessaging.getInstance().getToken().addOnCompleteListener(task -> {
            if (task.isSuccessful()) dispatchPushToken(task.getResult(), "granted");
            else dispatchPushToken(null, "error");
        });
    }

    private void dispatchPushToken(String token, String permission) {
        String tokenJson = token == null ? "null" : JSONObject.quote(token);
        String script = "window.dispatchEvent(new CustomEvent('aqura:fcm-token',{detail:{token:" +
                tokenJson + ",permission:" + JSONObject.quote(permission) + "}}));";
        runOnUiThread(() -> webView.evaluateJavascript(script, null));
    }

    private void openExternal(Uri uri) {
        try { startActivity(new Intent(Intent.ACTION_VIEW, uri)); }
        catch (ActivityNotFoundException ignored) { }
    }

    private void handleIntent(Intent intent) {
        Uri data = intent.getData();
        if (data != null && "aqura".equals(data.getScheme())) {
            String path = data.getQueryParameter("path");
            webView.loadUrl(BuildConfig.AQURA_URL + (path == null ? "" : path));
        } else {
            webView.loadUrl(BuildConfig.AQURA_URL);
        }
    }

    @Override protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        handleIntent(intent);
    }

    @Override protected void onDestroy() {
        if (webView != null) {
            webView.stopLoading();
            webView.destroy();
        }
        super.onDestroy();
    }
}
