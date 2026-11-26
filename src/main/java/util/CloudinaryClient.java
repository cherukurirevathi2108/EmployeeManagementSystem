package util;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.time.Duration;
import java.util.Properties;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Minimal signed-upload client for Cloudinary (no SDK needed).
 *
 * Credentials are NEVER stored in the code or the database. Set ONE of these on the server:
 *
 *   JVM option   -Dcloudinary.url=cloudinary://API_KEY:API_SECRET@CLOUD_NAME
 *   or env var   CLOUDINARY_URL=cloudinary://API_KEY:API_SECRET@CLOUD_NAME
 *
 * or a file  WEB-INF/cloudinary.properties  (never served to browsers) with
 *   cloud_name=...  api_key=...  api_secret=...   (see cloudinary.properties.example)
 *
 * or the three separate settings (system property / environment variable):
 *   cloudinary.cloud_name / CLOUDINARY_CLOUD_NAME
 *   cloudinary.api_key    / CLOUDINARY_API_KEY
 *   cloudinary.api_secret / CLOUDINARY_API_SECRET
 */
public final class CloudinaryClient {

    private static final Pattern SECURE_URL = Pattern.compile("\"secure_url\"\\s*:\\s*\"([^\"]+)\"");
    private static final Pattern MESSAGE = Pattern.compile("\"message\"\\s*:\\s*\"([^\"]*)\"");
    private static final HttpClient HTTP = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();

    private static final Properties FILE = loadFile();

    private final String cloudName, apiKey, apiSecret;

    private CloudinaryClient(String cloudName, String apiKey, String apiSecret) {
        this.cloudName = cloudName;
        this.apiKey = apiKey;
        this.apiSecret = apiSecret;
    }

    // ------------------------------------------------------------ configuration

    private static String setting(String prop, String env) {
        String v = System.getProperty(prop);
        if (v == null || v.trim().isEmpty()) v = System.getenv(env);
        return v == null || v.trim().isEmpty() ? null : v.trim();
    }

    private static Properties loadFile() {
        Properties p = new Properties();
        try (InputStream in = CloudinaryClient.class.getResourceAsStream("/cloudinary.properties")) {
            if (in != null) p.load(in);
        } catch (IOException ignore) { }
        return p;
    }

    /** Loads WEB-INF/cloudinary.properties (called once by the settings servlet with its real path). */
    public static void loadFrom(String path) {
        if (path == null) return;
        File f = new File(path);
        if (!f.isFile()) return;
        try (InputStream in = new FileInputStream(f)) {
            FILE.load(in);
        } catch (IOException ignore) { }
    }

    private static String fromFile(String key) {
        String v = FILE.getProperty(key);
        if (v == null || v.trim().isEmpty() || v.trim().startsWith("YOUR_")) return null;   // template placeholder
        return v.trim();
    }

    private static String[] readConfig() {
        String cloud = null, key = null, secret = null;
        String url = setting("cloudinary.url", "CLOUDINARY_URL");
        if (url != null && url.startsWith("cloudinary://")) {
            String rest = url.substring("cloudinary://".length());
            int at = rest.lastIndexOf('@'), colon = rest.indexOf(':');
            if (at > 0 && colon > 0 && colon < at) {
                key = rest.substring(0, colon);
                secret = rest.substring(colon + 1, at);
                cloud = rest.substring(at + 1);
            }
        }
        if (cloud == null) {
            cloud = setting("cloudinary.cloud_name", "CLOUDINARY_CLOUD_NAME");
            key = setting("cloudinary.api_key", "CLOUDINARY_API_KEY");
            secret = setting("cloudinary.api_secret", "CLOUDINARY_API_SECRET");
        }
        if (cloud == null) cloud = fromFile("cloud_name");
        if (key == null) key = fromFile("api_key");
        if (secret == null) secret = fromFile("api_secret");
        return new String[] { cloud, key, secret };
    }

    /** null when everything is set up correctly, otherwise a message for the admin. */
    public static String problem() {
        String[] c = readConfig();
        if (c[0] == null || c[1] == null || c[2] == null) {
            return "Cloudinary is not configured on the server yet (cloud name, API key and API secret are required).";
        }
        if (!c[0].matches("[A-Za-z0-9_-]{1,64}")) return "The Cloudinary cloud name looks invalid.";
        if (c[1].equals(c[2])) return "The Cloudinary API secret is identical to the API key - the secret is a different value.";
        return null;
    }

    public static CloudinaryClient fromConfig() {
        if (problem() != null) return null;
        String[] c = readConfig();
        return new CloudinaryClient(c[0], c[1], c[2]);
    }

    // ------------------------------------------------------------ upload

    /** Uploads an image and returns its https URL (secure_url). */
    public String uploadImage(byte[] data, String contentType, String folder) throws IOException {
        long ts = System.currentTimeMillis() / 1000L;
        // Cloudinary signature: SHA-1 of the sorted signed params + secret (file/api_key are not signed)
        String signature = sha1Hex("folder=" + folder + "&timestamp=" + ts + apiSecret);
        String boundary = "----SmartOfficeLogo" + Long.toHexString(System.nanoTime());

        ByteArrayOutputStream body = new ByteArrayOutputStream(data.length + 1024);
        field(body, boundary, "api_key", apiKey);
        field(body, boundary, "timestamp", String.valueOf(ts));
        field(body, boundary, "folder", folder);
        field(body, boundary, "signature", signature);
        write(body, "--" + boundary + "\r\nContent-Disposition: form-data; name=\"file\"; filename=\"logo\"\r\n"
                + "Content-Type: " + contentType + "\r\n\r\n");
        body.write(data);
        write(body, "\r\n--" + boundary + "--\r\n");

        HttpRequest req = HttpRequest.newBuilder(URI.create("https://api.cloudinary.com/v1_1/" + cloudName + "/image/upload"))
                .timeout(Duration.ofSeconds(40))
                .header("Content-Type", "multipart/form-data; boundary=" + boundary)
                .POST(HttpRequest.BodyPublishers.ofByteArray(body.toByteArray()))
                .build();

        HttpResponse<String> res;
        try {
            res = HTTP.send(req, HttpResponse.BodyHandlers.ofString());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IOException("Upload was interrupted");
        }
        String json = res.body() == null ? "" : res.body();
        if (res.statusCode() / 100 != 2) {
            Matcher m = MESSAGE.matcher(json);
            throw new IOException("Cloudinary returned HTTP " + res.statusCode() + (m.find() ? ": " + m.group(1) : ""));
        }
        Matcher m = SECURE_URL.matcher(json);
        if (!m.find()) throw new IOException("Cloudinary response did not contain an image URL");
        return m.group(1).replace("\\/", "/");
    }

    private static void field(ByteArrayOutputStream out, String boundary, String name, String value) throws IOException {
        write(out, "--" + boundary + "\r\nContent-Disposition: form-data; name=\"" + name + "\"\r\n\r\n" + value + "\r\n");
    }

    private static void write(ByteArrayOutputStream out, String s) throws IOException {
        out.write(s.getBytes(StandardCharsets.UTF_8));
    }

    private static String sha1Hex(String s) throws IOException {
        try {
            byte[] d = MessageDigest.getInstance("SHA-1").digest(s.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : d) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (NoSuchAlgorithmException e) {
            throw new IOException(e);
        }
    }
}
