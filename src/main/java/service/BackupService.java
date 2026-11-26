package service;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.PosixFilePermissions;
import java.security.MessageDigest;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import DAO.BackupHistoryDAO;
import model.BackupHistory;
import model.DBcConnection;

/**
 * Database backup and (guarded) restore using the MySQL command-line tools.
 *
 * Security notes:
 *  - The commands are run as an argument list, never through a shell, and no
 *    part of any argument comes from the user (file names are generated here).
 *  - The DB password is passed through the MYSQL_PWD environment variable, so
 *    it does not appear in the process list.
 *  - Backups are written OUTSIDE the web application. Only the file NAME is
 *    stored in backup_history and shown in the UI; the directory is server config.
 *
 * Configuration (JVM -D property or environment variable):
 *   smartoffice.backup.dir     / SMARTOFFICE_BACKUP_DIR     default: ~/smartoffice_backups
 *   smartoffice.mysqldump      / MYSQLDUMP_PATH             default: mysqldump
 *   smartoffice.mysql          / MYSQL_PATH                 default: mysql
 *   smartoffice.restore.enabled/ SMARTOFFICE_RESTORE_ENABLED default: false
 */
public final class BackupService {

    private static final AtomicBoolean BUSY = new AtomicBoolean(false);
    private static final Pattern SAFE_NAME = Pattern.compile("^[A-Za-z0-9_.-]{1,200}\\.sql$");
    private static final Pattern JDBC = Pattern.compile("^jdbc:mysql://([^:/]+)(?::(\\d+))?/([^?]+).*$");
    private static final long TIMEOUT_MIN = 10;

    private BackupService() { }

    private static String setting(String prop, String env, String def) {
        String v = System.getProperty(prop);
        if (v == null || v.isEmpty()) v = System.getenv(env);
        return (v == null || v.isEmpty()) ? def : v;
    }

    public static boolean restoreEnabled() {
        return "true".equalsIgnoreCase(setting("smartoffice.restore.enabled", "SMARTOFFICE_RESTORE_ENABLED", "false"));
    }

    private static File backupDir() throws IOException {
        File d = new File(setting("smartoffice.backup.dir", "SMARTOFFICE_BACKUP_DIR",
                new File(System.getProperty("user.home"), "smartoffice_backups").getPath()));
        Files.createDirectories(d.toPath());
        try {
            Files.setPosixFilePermissions(d.toPath(), PosixFilePermissions.fromString("rwx------"));
        } catch (Exception notPosix) { /* Windows: rely on directory ACLs */ }
        return d;
    }

    // ------------------------------------------------------------------ backup

    /** Runs a full backup and records the outcome (SUCCESS or FAILED) in backup_history. */
    public static BackupHistory runBackup(String adminId, String remarksPrefix) {
        BackupHistory h = new BackupHistory();
        h.setBackupType("FULL");
        h.setCreatedBy(adminId);

        if (!BUSY.compareAndSet(false, true)) {
            h.setBackupFile("-");
            h.setStatus("FAILED");
            h.setRemarks("Another backup or restore is already running.");
            return h;   // not stored: nothing was attempted
        }

        File out = null;
        try {
            String name = "smartoffice_" + new SimpleDateFormat("yyyyMMdd_HHmmss").format(new Date()) + ".sql";
            h.setBackupFile(name);
            File dir = backupDir();
            out = new File(dir, name);
            File err = File.createTempFile("mysqldump-err", ".txt");

            String[] conn = connection();
            ProcessBuilder pb = new ProcessBuilder(
                    setting("smartoffice.mysqldump", "MYSQLDUMP_PATH", "mysqldump"),
                    "--host=" + conn[0], "--port=" + conn[1], "--user=" + DBcConnection.getUser(),
                    "--single-transaction", "--routines", "--triggers",
                    "--result-file=" + out.getPath(), conn[2]);
            pb.environment().put("MYSQL_PWD", DBcConnection.getPassword());
            pb.redirectOutput(ProcessBuilder.Redirect.DISCARD);
            pb.redirectError(err);

            Process p = pb.start();
            boolean finished = p.waitFor(TIMEOUT_MIN, TimeUnit.MINUTES);
            if (!finished) {
                p.destroyForcibly();
                throw new IOException("mysqldump timed out after " + TIMEOUT_MIN + " minutes");
            }
            if (p.exitValue() != 0 || !out.exists() || out.length() == 0) {
                String msg = new String(Files.readAllBytes(err.toPath()));
                throw new IOException("mysqldump exit code " + p.exitValue() + ": " + trim(msg, 400));
            }
            Files.deleteIfExists(err.toPath());

            try {
                Files.setPosixFilePermissions(out.toPath(), PosixFilePermissions.fromString("rw-------"));
            } catch (Exception notPosix) { }

            h.setStatus("SUCCESS");
            h.setFileSize(out.length());
            h.setChecksum(sha256(out.toPath()));
            h.setRemarks(join(remarksPrefix, "Full backup completed."));
        } catch (Exception e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            h.setStatus("FAILED");
            h.setFileSize(0);
            h.setRemarks(join(remarksPrefix, trim(e.getMessage(), 500)));
            if (out != null) out.delete();   // never keep a partial dump
        } finally {
            BUSY.set(false);
        }

        try {
            h.setId(new BackupHistoryDAO().insert(h));
        } catch (Exception e) {
            System.err.println("[BackupService] could not record backup history: " + e.getMessage());
        }
        return h;
    }

    // ------------------------------------------------------------------ restore

    /** Returns null if the backup may be restored, otherwise the reason it may not. */
    public static String verify(BackupHistory b) {
        try {
            if (b == null) return "Backup not found.";
            if (!"SUCCESS".equals(b.getStatus())) return "Only a backup that finished successfully can be restored.";
            if (b.getChecksum() == null || b.getChecksum().isEmpty()) return "This backup has no recorded checksum.";
            File f = resolve(b.getBackupFile());
            if (!f.isFile()) return "The backup file is missing from the server.";
            if (f.length() != b.getFileSize()) return "The backup file size does not match the record.";
            if (!b.getChecksum().equalsIgnoreCase(sha256(f.toPath()))) return "Checksum mismatch: the backup file was modified.";
            return null;
        } catch (Exception e) {
            return "The backup could not be verified.";
        }
    }

    /**
     * Restores a verified backup. Takes a safety backup of the current database first and
     * aborts if that fails. NOTE: audit_logs is part of the dump, so audit rows written
     * after the chosen backup are reverted by a restore; the restore itself is audited
     * after it completes, so that entry survives.
     * @return null on success, otherwise a short error message
     */
    public static String restore(BackupHistory b, String adminId) {
        if (!restoreEnabled()) return "Restore is disabled on this server.";
        String problem = verify(b);
        if (problem != null) return problem;

        BackupHistory safety = runBackup(adminId, "Automatic safety backup before restore of " + b.getBackupFile() + ". ");
        if (!"SUCCESS".equals(safety.getStatus())) return "Safety backup failed, restore aborted.";

        if (!BUSY.compareAndSet(false, true)) return "Another backup or restore is already running.";
        try {
            File in = resolve(b.getBackupFile());
            String[] conn = connection();
            ProcessBuilder pb = new ProcessBuilder(
                    setting("smartoffice.mysql", "MYSQL_PATH", "mysql"),
                    "--host=" + conn[0], "--port=" + conn[1], "--user=" + DBcConnection.getUser(), conn[2]);
            pb.environment().put("MYSQL_PWD", DBcConnection.getPassword());
            pb.redirectInput(in);
            pb.redirectOutput(ProcessBuilder.Redirect.DISCARD);
            File err = File.createTempFile("mysql-restore-err", ".txt");
            pb.redirectError(err);
            Process p = pb.start();
            if (!p.waitFor(TIMEOUT_MIN, TimeUnit.MINUTES)) {
                p.destroyForcibly();
                return "Restore timed out; the database may be in a partial state. Use the safety backup.";
            }
            if (p.exitValue() != 0) {
                return "Restore failed: " + trim(new String(Files.readAllBytes(err.toPath())), 300);
            }
            Files.deleteIfExists(err.toPath());
            return null;
        } catch (Exception e) {
            if (e instanceof InterruptedException) Thread.currentThread().interrupt();
            return "Restore failed: " + trim(e.getMessage(), 300);
        } finally {
            BUSY.set(false);
        }
    }

    // ------------------------------------------------------------------ download

    /** Outcome of checking a backup for download: the file, or the reason it cannot be downloaded. */
    public static final class Download {
        public final File file;
        public final String error;
        private Download(File file, String error) { this.file = file; this.error = error; }
    }

    /**
     * Finds the file of a successful backup for download. The name comes from the history record
     * (never from the browser), must resolve inside the backup folder, and the size / checksum
     * must still match what was recorded when the backup was taken.
     */
    public static Download forDownload(BackupHistory b) {
        try {
            if (b == null) return new Download(null, "Backup not found.");
            if (!"SUCCESS".equals(b.getStatus())) return new Download(null, "Only a backup that finished successfully can be downloaded.");
            File f = resolve(b.getBackupFile());
            if (!f.isFile()) return new Download(null, "The backup file is missing from the server.");
            if (b.getFileSize() > 0 && f.length() != b.getFileSize()) return new Download(null, "The backup file size does not match the record, so it was not downloaded.");
            if (b.getChecksum() != null && !b.getChecksum().isEmpty()
                    && !b.getChecksum().equalsIgnoreCase(sha256(f.toPath()))) {
                return new Download(null, "Checksum mismatch: the backup file was modified, so it was not downloaded.");
            }
            return new Download(f, null);
        } catch (Exception e) {
            return new Download(null, "The backup could not be verified.");
        }
    }

    // ------------------------------------------------------------------ helpers

    /** Maps a stored file name to a file inside the backup directory; rejects anything else. */
    private static File resolve(String name) throws IOException {
        if (name == null || !SAFE_NAME.matcher(name).matches()) throw new IOException("Invalid backup file name");
        File dir = backupDir().getCanonicalFile();
        File f = new File(dir, name).getCanonicalFile();
        if (!f.getParentFile().equals(dir)) throw new IOException("Invalid backup file path");
        return f;
    }

    private static String[] connection() throws IOException {
        Matcher m = JDBC.matcher(DBcConnection.getUrl());
        if (!m.matches()) throw new IOException("Cannot read database host/name from the JDBC URL");
        return new String[] { m.group(1), m.group(2) == null ? "3306" : m.group(2), m.group(3) };
    }

    private static String sha256(Path path) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        try (InputStream in = Files.newInputStream(path)) {
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) md.update(buf, 0, n);
        }
        StringBuilder sb = new StringBuilder();
        for (byte x : md.digest()) sb.append(String.format("%02x", x));
        return sb.toString();
    }

    private static String trim(String s, int n) {
        if (s == null) return "";
        s = s.trim();
        return s.length() > n ? s.substring(0, n) : s;
    }

    private static String join(String prefix, String rest) {
        return prefix == null ? rest : prefix + rest;
    }
}
