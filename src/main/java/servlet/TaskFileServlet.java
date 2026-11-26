

package servlet;

import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

import DAO.TaskDAO;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import model.Task;

@WebServlet("/task-file")
public class TaskFileServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private final TaskDAO taskDAO = new TaskDAO();

    private Path getUploadDirectory() {
        return Paths.get(
            System.getProperty("user.home"),
            "employee-task-uploads"
        ).toAbsolutePath().normalize();
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null || session.getAttribute("role") == null) {
            response.sendRedirect(
                request.getContextPath() + "/login.html"
            );
            return;
        }

        String role = String.valueOf(session.getAttribute("role"));
        String taskIdText = request.getParameter("id");
        String type = request.getParameter("type");

        if (taskIdText == null || type == null) {
            response.sendError(
                HttpServletResponse.SC_BAD_REQUEST,
                "Task ID and file type are required."
            );
            return;
        }

        if (!"instruction".equalsIgnoreCase(type)
                && !"proof".equalsIgnoreCase(type)) {
            response.sendError(
                HttpServletResponse.SC_BAD_REQUEST,
                "Invalid file type."
            );
            return;
        }

        try {
            int taskId = Integer.parseInt(taskIdText);

            if (taskId <= 0) {
                response.sendError(
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Invalid task ID."
                );
                return;
            }

            Task task = taskDAO.getTaskById(taskId);

            if (task == null) {
                response.sendError(
                    HttpServletResponse.SC_NOT_FOUND,
                    "Task not found."
                );
                return;
            }

            /*
             * AUTHORIZATION
             */

            boolean authorized = false;

            if ("ADMIN".equalsIgnoreCase(role)) {

                authorized = true;

            } else if ("MANAGER".equalsIgnoreCase(role)) {

                Object managerValue = session.getAttribute("managerId");

                if (managerValue != null) {
                    String managerId = managerValue.toString();

                    authorized = taskDAO.isCreatedByManager(
                        taskId,
                        managerId
                    );
                }

            } else if ("EMPLOYEE".equalsIgnoreCase(role)) {

                Object employeeValue = session.getAttribute("employeeId");

                if (employeeValue != null) {
                    String employeeId = employeeValue.toString();

                    authorized = taskDAO.isAssignedToEmployee(
                        taskId,
                        employeeId
                    );
                }
            }

            if (!authorized) {
                response.sendError(
                    HttpServletResponse.SC_FORBIDDEN,
                    "You are not authorized to access this file."
                );
                return;
            }

            /*
             * GET STORED FILE VALUE
             */

            String storedFiles;

            if ("instruction".equalsIgnoreCase(type)) {
                storedFiles = task.getInstructionFile();
            } else {
                storedFiles = task.getWorkProofFile();
            }

            if (storedFiles == null || storedFiles.trim().isEmpty()) {
                response.sendError(
                    HttpServletResponse.SC_NOT_FOUND,
                    "No file has been uploaded for this task."
                );
                return;
            }

            /*
             * SELECT ONE FILE FROM MULTIPLE PROOFS
             *
             * Old URLs without fileIndex open the first proof.
             * Instruction files remain single-file attachments.
             */

            String storedFile;

            if ("instruction".equalsIgnoreCase(type)) {

                storedFile = storedFiles.trim();

            } else {

                String[] proofFiles = storedFiles.split("\\|");

                String fileIndexText = request.getParameter("fileIndex");
                int fileIndex = 0;

                if (fileIndexText != null && !fileIndexText.trim().isEmpty()) {
                    try {
                        fileIndex = Integer.parseInt(fileIndexText);
                    } catch (NumberFormatException ex) {
                        response.sendError(
                            HttpServletResponse.SC_BAD_REQUEST,
                            "Invalid proof file index."
                        );
                        return;
                    }
                }

                if (fileIndex < 0 || fileIndex >= proofFiles.length) {
                    response.sendError(
                        HttpServletResponse.SC_NOT_FOUND,
                        "The requested proof file does not exist."
                    );
                    return;
                }

                storedFile = proofFiles[fileIndex].trim();
            }

            if (storedFile.isEmpty()
                    || storedFile.contains("/")
                    || storedFile.contains("\\")
                    || storedFile.contains("..")) {
                response.sendError(
                    HttpServletResponse.SC_BAD_REQUEST,
                    "Invalid file name."
                );
                return;
            }

            /*
             * FIND FILE ON SERVER
             */

            Path uploadDirectory = getUploadDirectory();

            Path filePath = uploadDirectory
                .resolve(storedFile)
                .normalize();

            if (!filePath.startsWith(uploadDirectory)
                    || !Files.isRegularFile(filePath)) {
                response.sendError(
                    HttpServletResponse.SC_NOT_FOUND,
                    "File not found on the server."
                );
                return;
            }

            /*
             * DETERMINE CONTENT TYPE
             */

            String extension = "";
            int dot = storedFile.lastIndexOf('.');

            if (dot >= 0) {
                extension = storedFile.substring(dot).toLowerCase();
            }

            String contentType;

            if (".pdf".equals(extension)) {

                contentType = "application/pdf";

            } else if (".doc".equals(extension)) {

                contentType = "application/msword";

            } else if (".docx".equals(extension)) {

                contentType =
                    "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

            } else {

                response.sendError(
                    HttpServletResponse.SC_UNSUPPORTED_MEDIA_TYPE,
                    "Unsupported file type."
                );
                return;
            }

            /*
             * SEND THE SELECTED FILE
             */

            String displayName =
                ("instruction".equalsIgnoreCase(type)
                    ? "task-instruction"
                    : "employee-work-proof")
                + extension;

            response.setContentType(contentType);
            response.setHeader(
                "Content-Disposition",
                "inline; filename=\"" + displayName + "\""
            );

            response.setContentLengthLong(Files.size(filePath));

            try (InputStream input = Files.newInputStream(filePath)) {
                input.transferTo(response.getOutputStream());
                response.getOutputStream().flush();
            }

        } catch (NumberFormatException ex) {

            response.sendError(
                HttpServletResponse.SC_BAD_REQUEST,
                "Invalid task ID."
            );

        } catch (IOException ex) {

            throw ex;

        } catch (Exception ex) {

            getServletContext().log(
                "Error opening task attachment",
                ex
            );

            if (!response.isCommitted()) {
                response.sendError(
                    HttpServletResponse.SC_INTERNAL_SERVER_ERROR,
                    "Unable to open the requested file."
                );
            }
        }
    }
}
