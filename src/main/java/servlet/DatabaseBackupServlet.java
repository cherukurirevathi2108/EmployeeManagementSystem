package servlet;

import java.io.File;
import java.io.IOException;
import java.io.OutputStream;
import java.nio.file.Files;
import java.sql.SQLException;
import java.util.LinkedHashMap;
import java.util.Map;

import DAO.BackupHistoryDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import model.BackupHistory;
import service.AuditService;
import service.BackupService;
import util.Json;
import util.Security;
import util.SystemLogger;
import util.Web;

/**
 * Backup history, "Run backup", guarded restore and download. ADMIN only (SystemAccessFilter),
 * all POSTs CSRF-checked. A download is requested by backup id only: the file name comes from
 * the history record, must resolve inside the backup folder and must still match its recorded
 * size / checksum. The folder path on the server is never sent to the browser, and every
 * download is written to the audit log.
 */
@WebServlet("/system/backups")
public class DatabaseBackupServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        if (req.getParameter("download") != null) {
            download(req, res);
            return;
        }
        String m = req.getParameter("msg");
        if ("ok".equals(m)) req.setAttribute("message", "Backup completed successfully.");
        else if ("restored".equals(m)) req.setAttribute("message", "Database restored. Please log in again if your session no longer works.");
        else if ("failed".equals(m)) req.setAttribute("error", "The backup failed. See the remarks column for the reason.");
        render(req, res);
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        String adminId = Security.userId(req.getSession(false));
        if (!Security.hasRole(req.getSession(false), "ADMIN")) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }
        String action = req.getParameter("action");

        if ("backup".equals(action)) {
            BackupHistory h = BackupService.runBackup(adminId, null);
            AuditService.log(req, "BACKUP", "CREATE", h.getBackupFile(),
                    "Database backup " + h.getStatus(), null,
                    AuditService.map("status", h.getStatus(), "file", h.getBackupFile(), "size_bytes", h.getFileSize()));
            res.sendRedirect(req.getContextPath() + "/system/backups?msg="
                    + ("SUCCESS".equals(h.getStatus()) ? "ok" : "failed"));
            return;
        }

        if ("restore".equals(action)) {
            try {
                long id = Long.parseLong(Web.str(req, "backupId", 18) == null ? "0" : Web.str(req, "backupId", 18));
                BackupHistory b = new BackupHistoryDAO().getById(id);
                String typed = Web.str(req, "confirmText", 80);

                if (b == null) {
                    fail(req, res, "Backup not found.");
                    return;
                }
                // the admin has to type the exact file name they intend to restore
                if (typed == null || !typed.equals("RESTORE " + b.getBackupFile())) {
                    fail(req, res, "Confirmation text did not match. Type: RESTORE " + b.getBackupFile());
                    return;
                }
                AuditService.log(req, "BACKUP", "RESTORE_REQUESTED", b.getBackupFile(),
                        "Restore requested for backup #" + b.getId(), null, null);
                String error = BackupService.restore(b, adminId);
                if (error != null) {
                    AuditService.log(req, "BACKUP", "RESTORE_FAILED", b.getBackupFile(), error, null, null);
                    fail(req, res, error);
                    return;
                }
                AuditService.log(req, "BACKUP", "RESTORE", b.getBackupFile(),
                        "Database restored from backup #" + b.getId(), null, null);
                res.sendRedirect(req.getContextPath() + "/system/backups?msg=restored");
            } catch (NumberFormatException e) {
                fail(req, res, "Invalid backup selected.");
            } catch (SQLException e) {
                SystemLogger.error("Backup", e, req);
                fail(req, res, "Could not read backup history. The problem has been logged.");
            }
            return;
        }

        res.sendError(HttpServletResponse.SC_BAD_REQUEST);
    }

    /** GET ?download=ID streams the backup; GET ?download=ID&check=1 only answers whether it can be downloaded. */
    private void download(HttpServletRequest req, HttpServletResponse res) throws IOException {
        if (!Security.hasRole(req.getSession(false), "ADMIN")) {
            res.sendError(HttpServletResponse.SC_FORBIDDEN);
            return;
        }
        boolean checkOnly = "1".equals(req.getParameter("check"));
        BackupHistory b = null;
        String error = null;
        try {
            String idText = Web.str(req, "download", 18);
            b = new BackupHistoryDAO().getById(Long.parseLong(idText == null ? "0" : idText));
        } catch (NumberFormatException e) {
            error = "Invalid backup selected.";
        } catch (SQLException e) {
            SystemLogger.error("Backup", e, req);
            error = "Could not read backup history. The problem has been logged.";
        }
        BackupService.Download d = null;
        if (error == null) {
            d = BackupService.forDownload(b);
            error = d.error;
        }

        if (checkOnly) {
            Map<String, Object> out = new LinkedHashMap<>();
            out.put("ok", error == null);
            if (error != null) out.put("message", error);
            res.setContentType("application/json");
            res.setCharacterEncoding("UTF-8");
            res.setHeader("Cache-Control", "no-store");
            res.getWriter().write(Json.of(out));
            return;
        }
        if (error != null) {
            res.sendError(HttpServletResponse.SC_NOT_FOUND);
            return;
        }

        File f = d.file;
        AuditService.log(req, "BACKUP", "EXPORT", b.getBackupFile(),
                "Backup file downloaded", null,
                AuditService.map("file", b.getBackupFile(), "size_bytes", f.length()));
        String name = b.getBackupFile().replaceAll("[^A-Za-z0-9._-]", "_");
        res.setContentType("application/octet-stream");
        res.setHeader("Content-Disposition", "attachment; filename=\"" + name + "\"");
        res.setHeader("X-Content-Type-Options", "nosniff");
        res.setHeader("Cache-Control", "no-store");
        res.setContentLengthLong(f.length());
        try (OutputStream out = res.getOutputStream()) {
            Files.copy(f.toPath(), out);
        }
    }

    private void fail(HttpServletRequest req, HttpServletResponse res, String message)
            throws ServletException, IOException {
        req.setAttribute("error", message);
        render(req, res);
    }

    private void render(HttpServletRequest req, HttpServletResponse res) throws ServletException, IOException {
        try {
            req.setAttribute("history", new BackupHistoryDAO().getAll(100));
        } catch (SQLException e) {
            SystemLogger.error("Backup", e, req);
            req.setAttribute("history", java.util.Collections.emptyList());
            if (req.getAttribute("error") == null) req.setAttribute("error", "Backup history could not be loaded.");
        }
        req.setAttribute("restoreEnabled", BackupService.restoreEnabled());
        req.getRequestDispatcher("/WEB-INF/admin/backup-management.jsp").forward(req, res);
    }
}
