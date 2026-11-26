
package servlet;

import java.io.IOException;
import java.io.OutputStream;
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

@WebServlet("/workProof")
public class WorkProofServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private final TaskDAO taskDAO = new TaskDAO();

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null ||
                !"ADMIN".equalsIgnoreCase(
                    String.valueOf(session.getAttribute("role")))) {
            response.sendError(
                HttpServletResponse.SC_FORBIDDEN,
                "Admin access required."
            );
            return;
        }

        try {
            int taskId = Integer.parseInt(
                request.getParameter("id"));

            Task task = taskDAO.getTaskById(taskId);

            if (task == null ||
                    task.getWorkProofFile() == null ||
                    task.getWorkProofFile().trim().isEmpty()) {
                response.sendError(
                    HttpServletResponse.SC_NOT_FOUND,
                    "No work proof uploaded for this task."
                );
                return;
            }

            String fileName = Paths.get(
                task.getWorkProofFile()
            ).getFileName().toString();

            Path uploadDirectory = Paths.get(
                System.getProperty("user.home"),
                "employee-task-uploads"
            ).toAbsolutePath().normalize();

            Path file = uploadDirectory.resolve(fileName)
                                       .normalize();

            if (!file.startsWith(uploadDirectory)
                    || !Files.isRegularFile(file)) {
                response.sendError(
                    HttpServletResponse.SC_NOT_FOUND,
                    "Uploaded work proof file was not found."
                );
                return;
            }

            String contentType =
                Files.probeContentType(file);

            if (contentType == null) {
                contentType = "application/octet-stream";
            }

            response.setContentType(contentType);
            response.setHeader(
                "Content-Disposition",
                "inline; filename=\"" + fileName + "\""
            );
            response.setContentLengthLong(Files.size(file));

            try (OutputStream out = response.getOutputStream()) {
                Files.copy(file, out);
            }

        } catch (NumberFormatException e) {
            response.sendError(
                HttpServletResponse.SC_BAD_REQUEST,
                "Invalid task ID."
            );
        }
    }
}
