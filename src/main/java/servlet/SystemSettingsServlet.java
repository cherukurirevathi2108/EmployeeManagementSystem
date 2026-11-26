package servlet;

import java.io.IOException;
import java.io.InputStream;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;
import service.SystemSettingsService;
import util.CloudinaryClient;
import util.Json;
import util.Security;
import util.SystemLogger;

/**
 * System settings (ADMIN only).
 *  - Save settings: normal form post, only the fields present in the form are changed.
 *  - Company logo: uploaded straight to Cloudinary (action=uploadLogo) or removed (action=removeLogo);
 *    these two answer with a small JSON object. Only the resulting https URL is stored.
 * Role and CSRF checks are done by SystemAccessFilter; the role is re-checked on POST here.
 */
@WebServlet("/system/settings")
@MultipartConfig(maxFileSize = 2L * 1024 * 1024, maxRequestSize = 4L * 1024 * 1024)
public class SystemSettingsServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private static final int MAX_LOGO_BYTES = 2 * 1024 * 1024;

    @Override
    public void init() throws ServletException {
        // credentials live in WEB-INF/cloudinary.properties (not reachable from a browser)
        CloudinaryClient.loadFrom(getServletContext().getRealPath("/WEB-INF/cloudinary.properties"));
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if ("1".equals(req.getParameter("saved"))) req.setAttribute("message", "Settings saved.");
        else if ("0".equals(req.getParameter("saved"))) req.setAttribute("message", "No changes to save.");
        render(req, res, null, null);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if (!Security.hasRole(req.getSession(false), "ADMIN")) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }
        String action = req.getParameter("action");
        if ("uploadLogo".equals(action) || "removeLogo".equals(action)) {
            handleLogo(req, res, action);
            return;
        }

        // ---- Save settings: only keys that are in the form are touched ----
        Map<String, String> submitted = new LinkedHashMap<>();
        for (String key : SystemSettingsService.DEFINITIONS.keySet()) {
            if ("company_logo".equals(key) || "date_format".equals(key) || "time_format".equals(key)) continue;
            if ("working_days".equals(key)) {
                String[] days = req.getParameterValues("working_days");
                submitted.put(key, days == null ? "" : String.join(",", days));
                continue;
            }
            String raw = req.getParameter(key);
            if (raw == null) continue;                       // not part of this form: leave unchanged
            raw = raw.trim();
            submitted.put(key, raw.length() > 300 ? raw.substring(0, 300) : raw);
        }
        // the single "Date & time format" select carries both values as "dateFormat|timeFormat"
        String dt = req.getParameter("datetime_format");
        if (dt != null && dt.indexOf('|') > 0) {
            submitted.put("date_format", dt.substring(0, dt.indexOf('|')));
            submitted.put("time_format", dt.substring(dt.indexOf('|') + 1));
        }

        try {
            SystemSettingsService.Result r = SystemSettingsService.update(
                    submitted, Security.userId(req.getSession(false)), req);
            if (r.ok()) {
                res.sendRedirect(req.getContextPath() + "/system/settings?saved=" + (r.changed > 0 ? 1 : 0));
                return;
            }
            render(req, res, r.errors, submitted);           // show the problems with what the admin typed
        } catch (SQLException e) {
            SystemLogger.error("SystemSettings", e, req);
            List<String> errs = new ArrayList<>();
            errs.add("Settings could not be saved. The problem has been logged.");
            render(req, res, errs, submitted);
        }
    }

    // ------------------------------------------------------------------ company logo (JSON)

    private void handleLogo(HttpServletRequest req, HttpServletResponse res, String action) throws IOException {
        Map<String, Object> out = new LinkedHashMap<>();
        try {
            String adminId = Security.userId(req.getSession(false));
            if ("removeLogo".equals(action)) {
                SystemSettingsService.Result r = SystemSettingsService.update(one(""), adminId, req);
                if (r.ok()) { out.put("ok", true); out.put("url", ""); out.put("message", "Logo removed."); }
                else fail(out, String.join(" ", r.errors));
            } else {
                String problem = CloudinaryClient.problem();
                Part part = problem == null ? req.getPart("logo") : null;
                if (problem != null) {
                    fail(out, problem);
                } else if (part == null || part.getSize() == 0) {
                    fail(out, "Choose an image to upload.");
                } else if (part.getSize() > MAX_LOGO_BYTES) {
                    fail(out, "The image must be 2 MB or smaller.");
                } else {
                    byte[] data;
                    try (InputStream in = part.getInputStream()) { data = in.readNBytes(MAX_LOGO_BYTES + 1); }
                    String type = sniff(data);
                    if (type == null) {
                        fail(out, "Only PNG, JPG or WebP images are allowed.");
                    } else {
                        String url = CloudinaryClient.fromConfig().uploadImage(data, type, "smartoffice/logo");
                        SystemSettingsService.Result r = SystemSettingsService.update(one(url), adminId, req);
                        if (r.ok()) { out.put("ok", true); out.put("url", url); out.put("message", "Logo updated."); }
                        else fail(out, String.join(" ", r.errors));
                    }
                }
            }
        } catch (IllegalStateException tooBig) {
            fail(out, "The image must be 2 MB or smaller.");
        } catch (Exception e) {
            SystemLogger.error("CompanyLogo", e, req);
            fail(out, "The logo could not be uploaded. Check the Cloudinary settings on the server and try again. The problem has been logged.");
        }
        res.setContentType("application/json");
        res.setCharacterEncoding("UTF-8");
        res.setHeader("Cache-Control", "no-store");
        res.getWriter().write(Json.of(out));
    }

    private static void fail(Map<String, Object> out, String message) {
        out.clear();
        out.put("ok", false);
        out.put("message", message);
    }

    private static Map<String, String> one(String logo) {
        Map<String, String> m = new LinkedHashMap<>();
        m.put("company_logo", logo);
        return m;
    }

    /** Detects the real image type from the file's first bytes (the browser-sent type is not trusted). */
    private static String sniff(byte[] d) {
        if (d.length >= 8 && (d[0] & 0xFF) == 0x89 && d[1] == 'P' && d[2] == 'N' && d[3] == 'G') return "image/png";
        if (d.length >= 3 && (d[0] & 0xFF) == 0xFF && (d[1] & 0xFF) == 0xD8 && (d[2] & 0xFF) == 0xFF) return "image/jpeg";
        if (d.length >= 12 && d[0] == 'R' && d[1] == 'I' && d[2] == 'F' && d[3] == 'F'
                && d[8] == 'W' && d[9] == 'E' && d[10] == 'B' && d[11] == 'P') return "image/webp";
        return null;
    }

    private void render(HttpServletRequest req, HttpServletResponse res, List<String> errors,
                        Map<String, String> typed) throws ServletException, IOException {
        try {
            req.setAttribute("settings", SystemSettingsService.all());
        } catch (SQLException e) {
            SystemLogger.error("SystemSettings", e, req);
            if (errors == null) errors = new ArrayList<>();
            errors.add("Settings could not be loaded. The problem has been logged.");
        }
        req.setAttribute("configProblem", CloudinaryClient.problem());
        req.setAttribute("errors", errors);
        req.setAttribute("typed", typed);
        req.getRequestDispatcher("/WEB-INF/admin/system-settings.jsp").forward(req, res);
    }
}
