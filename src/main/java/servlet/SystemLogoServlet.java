package servlet;

import java.io.IOException;
import java.io.InputStream;
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
import util.Security;
import util.SystemLogger;

/**
 * Company logo upload (ADMIN only). The image is checked here, uploaded to Cloudinary,
 * and only the resulting https URL is stored in the "company_logo" system setting.
 * Role and CSRF checks are done by SystemAccessFilter; the role is re-checked here.
 */
@WebServlet("/system/logo")
@MultipartConfig(maxFileSize = 2L * 1024 * 1024, maxRequestSize = 3L * 1024 * 1024)
public class SystemLogoServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private static final int MAX_BYTES = 2 * 1024 * 1024;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if (!Security.hasRole(req.getSession(false), "ADMIN")) { res.sendError(HttpServletResponse.SC_FORBIDDEN); return; }
        show(req, res, new ArrayList<>());
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if (!Security.hasRole(req.getSession(false), "ADMIN")) { res.sendError(HttpServletResponse.SC_FORBIDDEN); return; }
        List<String> errors = new ArrayList<>();
        try {
            String adminId = Security.userId(req.getSession(false));
            if ("remove".equals(req.getParameter("action"))) {
                SystemSettingsService.Result r = SystemSettingsService.update(one(""), adminId, req);
                if (r.ok()) req.setAttribute("message", "Company logo removed."); else errors.addAll(r.errors);
            } else {
                String problem = CloudinaryClient.problem();
                Part part = problem == null ? req.getPart("logo") : null;
                if (problem != null) {
                    errors.add(problem);
                } else if (part == null || part.getSize() == 0) {
                    errors.add("Choose an image to upload.");
                } else if (part.getSize() > MAX_BYTES) {
                    errors.add("The image must be 2 MB or smaller.");
                } else {
                    byte[] data;
                    try (InputStream in = part.getInputStream()) { data = in.readNBytes(MAX_BYTES + 1); }
                    String type = sniff(data);
                    if (type == null) {
                        errors.add("Only PNG, JPG, GIF or WebP images are allowed.");
                    } else {
                        String url = CloudinaryClient.fromConfig().uploadImage(data, type, "smartoffice/logo");
                        SystemSettingsService.Result r = SystemSettingsService.update(one(url), adminId, req);
                        if (r.ok()) req.setAttribute("message", "Company logo uploaded and saved."); else errors.addAll(r.errors);
                    }
                }
            }
        } catch (Exception e) {
            SystemLogger.error("CompanyLogo", e, req);
            errors.add("The logo could not be uploaded. Check the Cloudinary settings on the server and try again. The problem has been logged.");
        }
        show(req, res, errors);
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
        if (d.length >= 6 && d[0] == 'G' && d[1] == 'I' && d[2] == 'F' && d[3] == '8') return "image/gif";
        if (d.length >= 12 && d[0] == 'R' && d[1] == 'I' && d[2] == 'F' && d[3] == 'F'
                && d[8] == 'W' && d[9] == 'E' && d[10] == 'B' && d[11] == 'P') return "image/webp";
        return null;
    }

    private void show(HttpServletRequest req, HttpServletResponse res, List<String> errors) throws ServletException, IOException {
        req.setAttribute("logoUrl", SystemSettingsService.get("company_logo", ""));
        req.setAttribute("configProblem", CloudinaryClient.problem());
        req.setAttribute("errors", errors);
        req.getRequestDispatcher("/WEB-INF/admin/system-logo.jsp").forward(req, res);
    }
}
