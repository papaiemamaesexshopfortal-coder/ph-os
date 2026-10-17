package br.com.phservicefortal.phos;

import android.app.Activity;
import android.content.Intent;
import android.content.ClipData;
import android.net.Uri;
import android.os.Bundle;
import android.util.Base64;
import android.view.ViewGroup;
import android.webkit.JavascriptInterface;
import android.webkit.CookieManager;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import androidx.core.content.FileProvider;
import java.io.File;
import java.io.FileOutputStream;
import java.util.UUID;

public final class MainActivity extends Activity {
    private static final String APP_URL = "https://ph-os-kappa.vercel.app/";
    private static final String APP_HOST = "ph-os-kappa.vercel.app";
    private WebView webView;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        CookieManager.getInstance().setAcceptCookie(true);
        webView = new WebView(this);
        setContentView(webView, new ViewGroup.LayoutParams(-1, -1));
        configure(webView);
        if (state == null) webView.loadUrl(APP_URL);
        else webView.restoreState(state);
    }

    private void configure(WebView view) {
        WebSettings settings = view.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setSupportMultipleWindows(true);
        settings.setJavaScriptCanOpenWindowsAutomatically(true);
        settings.setAllowFileAccess(false);
        settings.setAllowContentAccess(false);
        settings.setMixedContentMode(WebSettings.MIXED_CONTENT_NEVER_ALLOW);
        view.addJavascriptInterface(new FileShareBridge(), "PHOSAndroid");
        view.setWebViewClient(new WebViewClient() {
            @Override public boolean shouldOverrideUrlLoading(WebView source, WebResourceRequest request) {
                return route(source, request.getUrl());
            }
            @Override public boolean shouldOverrideUrlLoading(WebView source, String url) {
                return route(source, Uri.parse(url));
            }
        });
        view.setWebChromeClient(new WebChromeClient() {
            @Override public boolean onCreateWindow(WebView parent, boolean dialog, boolean userGesture, android.os.Message resultMsg) {
                WebView popup = new WebView(MainActivity.this);
                configure(popup);
                popup.setWebViewClient(new WebViewClient() {
                    @Override public boolean shouldOverrideUrlLoading(WebView source, WebResourceRequest request) {
                        boolean handled = route(source, request.getUrl());
                        if (handled) source.post(source::destroy);
                        return handled;
                    }
                    @Override public boolean shouldOverrideUrlLoading(WebView source, String url) {
                        boolean handled = route(source, Uri.parse(url));
                        if (handled) source.post(source::destroy);
                        return handled;
                    }
                });
                ((WebView.WebViewTransport) resultMsg.obj).setWebView(popup);
                resultMsg.sendToTarget();
                return true;
            }
        });
    }

    private final class FileShareBridge {
        @JavascriptInterface
        public void sharePdf(String encoded, String fileName, String message) {
            runOnUiThread(() -> {
                try {
                    if (encoded == null || encoded.isEmpty()) throw new IllegalArgumentException("O PDF do recibo está vazio.");
                    File directory = new File(getCacheDir(), "shared");
                    if (!directory.exists() && !directory.mkdirs()) throw new IllegalStateException("Não foi possível preparar o PDF.");
                    File[] previous = directory.listFiles();
                    if (previous != null) {
                        long cutoff = System.currentTimeMillis() - 24L * 60L * 60L * 1000L;
                        for (File item : previous) if (item.lastModified() < cutoff) item.delete();
                    }
                    String safeName = fileName == null ? "recibo.pdf" : fileName.replaceAll("[^a-zA-Z0-9._-]", "_");
                    if (!safeName.toLowerCase().endsWith(".pdf")) safeName += ".pdf";
                    File pdf = new File(directory, UUID.randomUUID() + "-" + safeName);
                    byte[] bytes = Base64.decode(encoded, Base64.DEFAULT);
                    if (bytes.length < 8 || bytes[0] != '%' || bytes[1] != 'P' || bytes[2] != 'D' || bytes[3] != 'F') {
                        throw new IllegalArgumentException("O recibo gerado não é um PDF válido.");
                    }
                    try (FileOutputStream output = new FileOutputStream(pdf)) { output.write(bytes); }
                    Uri uri = FileProvider.getUriForFile(MainActivity.this, getPackageName() + ".fileprovider", pdf);
                    Intent share = new Intent(Intent.ACTION_SEND);
                    share.setType("application/pdf");
                    share.putExtra(Intent.EXTRA_STREAM, uri);
                    share.putExtra(Intent.EXTRA_SUBJECT, "Recibo de pagamento em PDF");
                    share.putExtra(Intent.EXTRA_TEXT, message == null ? "Segue o recibo em PDF." : message);
                    share.setClipData(ClipData.newUri(getContentResolver(), safeName, uri));
                    share.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    Intent chooser = Intent.createChooser(share, "Compartilhar recibo em PDF");
                    chooser.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    startActivity(chooser);
                } catch (Exception error) {
                    android.util.Log.e("PHOS", "Falha ao compartilhar recibo PDF", error);
                    android.widget.Toast.makeText(MainActivity.this, "Não foi possível compartilhar o recibo. Tente novamente.", android.widget.Toast.LENGTH_LONG).show();
                }
            });
        }
    }

    private boolean route(WebView source, Uri uri) {
        if ("https".equalsIgnoreCase(uri.getScheme()) && APP_HOST.equalsIgnoreCase(uri.getHost())) return false;
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (Exception ignored) { }
        return true;
    }

    @Override public void onSaveInstanceState(Bundle state) {
        webView.saveState(state);
        super.onSaveInstanceState(state);
    }

    @Override public void onBackPressed() {
        if (webView != null && webView.canGoBack()) webView.goBack();
        else super.onBackPressed();
    }
}
