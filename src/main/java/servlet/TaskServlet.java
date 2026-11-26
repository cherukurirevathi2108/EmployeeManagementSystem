


package servlet;

import java.io.IOException;
import java.io.PrintWriter;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Date;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import DAO.TaskDAO;
import model.Task;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

@WebServlet("/tasks")
@MultipartConfig(
    fileSizeThreshold = 1024 * 1024,
    maxFileSize = 10 * 1024 * 1024,
    maxRequestSize = 60 * 1024 * 1024
)
public class TaskServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;

    private final TaskDAO taskDAO = new TaskDAO();

    private Path getUploadDirectory() throws IOException {
        Path uploadDir = Paths.get(
            System.getProperty("user.home"),
            "employee-task-uploads"
        );

        Files.createDirectories(uploadDir);
        return uploadDir;
    }

    // Manager instructions: PDF, DOC and DOCX.
    private String saveUpload(Part part)
            throws IOException, ServletException {

        if (part == null || part.getSize() == 0) {
            return null;
        }

        String submittedName = part.getSubmittedFileName();

        if (submittedName == null || submittedName.trim().isEmpty()) {
            return null;
        }

        String originalName = Paths.get(submittedName)
                .getFileName().toString();

        String lowerName = originalName.toLowerCase();

        if (!(lowerName.endsWith(".pdf")
                || lowerName.endsWith(".doc")
                || lowerName.endsWith(".docx"))) {
            throw new ServletException(
                "Only PDF, DOC and DOCX files are allowed."
            );
        }

        String extension = originalName.substring(
            originalName.lastIndexOf(".")
        );

        String storedName = UUID.randomUUID().toString() + extension;
        Path target = getUploadDirectory().resolve(storedName);

        try (InputStream input = part.getInputStream()) {
            Files.copy(input, target);
        }

        return storedName;
    }

    // Employee work proofs: PDF only.
    private String saveProofUpload(Part part)
            throws IOException, ServletException {

        if (part == null || part.getSize() == 0) {
            return null;
        }

        String submittedName = part.getSubmittedFileName();

        if (submittedName == null || submittedName.trim().isEmpty()) {
            throw new ServletException("Please select a PDF file.");
        }

        String originalName = Paths.get(submittedName)
                .getFileName().toString();

        if (!originalName.toLowerCase().endsWith(".pdf")) {
            throw new ServletException(
                "Only PDF files are allowed for employee work proof."
            );
        }

        String storedName = UUID.randomUUID().toString() + ".pdf";
        Path target = getUploadDirectory().resolve(storedName);

        try (InputStream input = part.getInputStream()) {
            Files.copy(input, target);
        }

        return storedName;
    }

    private String value(
            HttpServletRequest request, String name) {

        String result = request.getParameter(name);
        return result == null ? "" : result.trim();
    }

    private void redirect(
            HttpServletRequest request,
            HttpServletResponse response,
            String message) throws IOException {

        response.sendRedirect(
            request.getContextPath()
                + "/managerDashboard.jsp?message="
                + URLEncoder.encode(message, StandardCharsets.UTF_8)
        );
    }

    private boolean isManager(HttpSession session) {
        if (session == null) {
            return false;
        }

        Object role = session.getAttribute("role");

        return role != null
            && "MANAGER".equalsIgnoreCase(role.toString());
    }

    private boolean isEmployee(HttpSession session) {
        if (session == null) {
            return false;
        }

        Object role = session.getAttribute("role");

        return role != null
            && "EMPLOYEE".equalsIgnoreCase(role.toString());
    }

    private boolean isAdmin(HttpSession session) {
        if (session == null) {
            return false;
        }

        Object role = session.getAttribute("role");

        return role != null
            && "ADMIN".equalsIgnoreCase(role.toString());
    }

    private String jsonEscape(String text) {
        if (text == null) {
            return "";
        }

        return text
            .replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "\\r")
            .replace("\t", "\\t");
    }

    private String getManagerId(HttpSession session) {
        Object id = session.getAttribute("employeeId");

        if (id == null) {
            id = session.getAttribute("managerId");
        }

        return id == null ? "" : id.toString();
    }

    private String getEmployeeId(HttpSession session) {
        Object id = session.getAttribute("employeeId");

        if (id == null) {
            id = session.getAttribute("empId");
        }

        return id == null ? "" : id.toString();
    }

    private void writeTeamsJson(
            HttpServletResponse response,
            String managerId) throws IOException {

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        List<String[]> teams =
            taskDAO.getTeamsByManager(managerId);

        PrintWriter out = response.getWriter();
        out.print("[");

        for (int i = 0; i < teams.size(); i++) {
            String[] team = teams.get(i);

            if (i > 0) {
                out.print(",");
            }

            out.print("{");
            out.print("\"id\":\"" + jsonEscape(team[0]) + "\",");
            out.print("\"name\":\"" + jsonEscape(team[1]) + "\"");
            out.print("}");
        }

        out.print("]");
        out.flush();
    }

    private void writeEmployeesJson(
            HttpServletRequest request,
            HttpServletResponse response,
            String managerId) throws IOException {

        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");

        String teamId = value(request, "teamId");
        PrintWriter out = response.getWriter();

        if (teamId.isEmpty()) {
            out.print("[]");
            out.flush();
            return;
        }

        List<String[]> employees =
            taskDAO.getEmployeesByManagerTeam(teamId, managerId);

        out.print("[");

        for (int i = 0; i < employees.size(); i++) {
            String[] employee = employees.get(i);

            if (i > 0) {
                out.print(",");
            }

            out.print("{");
            out.print("\"id\":\"" + jsonEscape(employee[0]) + "\",");
            out.print("\"name\":\"" + jsonEscape(employee[1]) + "\"");
            out.print("}");
        }

        out.print("]");
        out.flush();
    }

    @Override
    protected void doGet(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (session == null) {
            response.sendRedirect(
                request.getContextPath() + "/login.jsp"
            );
            return;
        }

        String action = value(request, "action");

        if ("ajaxTeams".equals(action)) {
            if (!isManager(session)) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }

            writeTeamsJson(response, getManagerId(session));
            return;
        }

        if ("ajaxEmployees".equals(action)) {
            if (!isManager(session)) {
                response.sendError(HttpServletResponse.SC_FORBIDDEN);
                return;
            }

            writeEmployeesJson(
                request, response, getManagerId(session)
            );
            return;
        }

        if (isManager(session)) {
            request.setAttribute(
                "tasks",
                taskDAO.getTasksByManager(getManagerId(session))
            );

            request.getRequestDispatcher(
                "/managerDashboard.jsp"
            ).forward(request, response);
            return;
        }

        if (isEmployee(session)) {
            request.setAttribute(
                "tasks",
                taskDAO.getTasksByEmployee(getEmployeeId(session))
            );

            request.getRequestDispatcher(
                "/employee_dashboard.jsp"
            ).forward(request, response);
            return;
        }

        if (isAdmin(session)) {
            request.setAttribute("tasks", taskDAO.getAllTasks());

            request.getRequestDispatcher(
                "/manageTasks.jsp"
            ).forward(request, response);
            return;
        }

        response.sendRedirect(
            request.getContextPath() + "/login.jsp"
        );
    }

    @Override
    protected void doPost(
            HttpServletRequest request,
            HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        HttpSession session = request.getSession(false);

        if (session == null) {
            response.sendRedirect(
                request.getContextPath() + "/login.jsp"
            );
            return;
        }

        String action = value(request, "action");

        try {

            // MANAGER: CREATE ONE GROUP OF TASKS FOR SELECTED EMPLOYEES
            if ("create".equals(action)) {

                if (!isManager(session)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String managerId = getManagerId(session);
                String title = value(request, "taskTitle");
                String description = value(request, "description");
                String department = value(request, "department");
                String priority = value(request, "priority");
                String startDateText = value(request, "startDate");
                String dueDateText = value(request, "dueDate");
                String teamId = value(request, "teamId");

                String[] selectedEmployees =
                    request.getParameterValues("assignedEmployees");

                if (title.isEmpty()
                        || description.isEmpty()
                        || department.isEmpty()
                        || priority.isEmpty()
                        || startDateText.isEmpty()
                        || dueDateText.isEmpty()
                        || teamId.isEmpty()) {

                    redirect(request, response,
                        "Please fill all required task fields.");
                    return;
                }

                if (selectedEmployees == null
                        || selectedEmployees.length == 0) {

                    redirect(request, response,
                        "Please select at least one team member.");
                    return;
                }

                Date startDate;
                Date dueDate;

                try {
                    startDate = Date.valueOf(startDateText);
                    dueDate = Date.valueOf(dueDateText);
                } catch (IllegalArgumentException e) {
                    redirect(request, response, "Invalid task dates.");
                    return;
                }

                if (dueDate.before(startDate)) {
                    redirect(request, response,
                        "Due date cannot be before start date.");
                    return;
                }

                Set<String> employeeIds = new LinkedHashSet<>();

                for (String employeeId : selectedEmployees) {
                    if (employeeId != null
                            && !employeeId.trim().isEmpty()) {
                        employeeIds.add(employeeId.trim());
                    }
                }

                if (employeeIds.isEmpty()) {
                    redirect(request, response,
                        "Please select at least one employee.");
                    return;
                }

                boolean managerOwnsTeam = false;

                List<String[]> managerTeams =
                    taskDAO.getTeamsByManager(managerId);

                for (String[] team : managerTeams) {
                    if (teamId.equals(team[0])) {
                        managerOwnsTeam = true;
                        break;
                    }
                }

                if (!managerOwnsTeam) {
                    redirect(request, response,
                        "Selected team is not assigned to you.");
                    return;
                }

                for (String employeeId : employeeIds) {
                    if (!taskDAO.isEmployeeInManagerTeam(
                            teamId, employeeId, managerId)) {

                        redirect(request, response,
                            "One or more selected employees are not active members of this team.");
                        return;
                    }
                }

                String instructionFile;

                try {
                    instructionFile =
                        saveUpload(request.getPart("instructionFile"));
                } catch (ServletException e) {
                    redirect(request, response, e.getMessage());
                    return;
                }

                /*
                 * IMPORTANT:
                 * Generate the group ID ONCE for this assignment.
                 * Every employee task record receives this same ID.
                 */
                String taskGroupId = UUID.randomUUID().toString();

                int successCount = 0;

                for (String employeeId : employeeIds) {
                    Task task = new Task();

                    task.setTaskGroupId(taskGroupId);
                    task.setTaskTitle(title);
                    task.setDescription(description);
                    task.setAssignedTo(employeeId);
                    task.setCreatedBy(managerId);
                    task.setDepartment(department);
                    task.setPriority(priority);
                    task.setStartDate(startDate);
                    task.setDueDate(dueDate);
                    task.setStatus("ASSIGNED");
                    task.setInstructionFile(instructionFile);

                    if (taskDAO.addTask(task)) {
                        successCount++;
                    }
                }

                if (successCount == employeeIds.size()) {
                    redirect(request, response,
                        "Task assigned successfully to "
                            + successCount + " employee(s).");
                } else if (successCount > 0) {
                    redirect(request, response,
                        "Task was assigned to " + successCount
                            + " employee(s), but some assignments failed.");
                } else {
                    redirect(request, response,
                        "Task assignment failed. Please check the database columns.");
                }

                return;
            }

            // MANAGER: UPDATE ONE EMPLOYEE'S TASK RECORD
            if ("update".equals(action)) {

                if (!isManager(session)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String managerId = getManagerId(session);
                int taskId = Integer.parseInt(value(request, "id"));

                if (!taskDAO.isCreatedByManager(taskId, managerId)) {
                    redirect(request, response,
                        "You cannot update this task.");
                    return;
                }

                String title = value(request, "taskTitle");
                String description = value(request, "description");
                String assignedTo = value(request, "assignedTo");
                String department = value(request, "department");
                String priority = value(request, "priority");
                String startText = value(request, "startDate");
                String dueText = value(request, "dueDate");

                if (title.isEmpty()
                        || description.isEmpty()
                        || assignedTo.isEmpty()
                        || department.isEmpty()
                        || priority.isEmpty()
                        || startText.isEmpty()
                        || dueText.isEmpty()) {

                    redirect(request, response,
                        "Please fill all required fields.");
                    return;
                }

                Date startDate = Date.valueOf(startText);
                Date dueDate = Date.valueOf(dueText);

                if (dueDate.before(startDate)) {
                    redirect(request, response,
                        "Due date cannot be before start date.");
                    return;
                }

                Task task = new Task();
                task.setId(taskId);
                task.setTaskTitle(title);
                task.setDescription(description);
                task.setAssignedTo(assignedTo);
                task.setCreatedBy(managerId);
                task.setDepartment(department);
                task.setPriority(priority);
                task.setStartDate(startDate);
                task.setDueDate(dueDate);

                boolean updated =
                    taskDAO.updateTaskByManager(task, managerId);

                if (!updated) {
                    redirect(request, response, "Task update failed.");
                    return;
                }

                try {
                    String fileName =
                        saveUpload(request.getPart("instructionFile"));

                    if (fileName != null) {
                        taskDAO.updateInstructionFile(
                            taskId, managerId, fileName
                        );
                    }
                } catch (ServletException e) {
                    redirect(request, response, e.getMessage());
                    return;
                }

                redirect(request, response, "Task updated successfully.");
                return;
            }

            // MANAGER: REVIEW ONE EMPLOYEE'S TASK ONLY
            if ("review".equals(action)) {

                if (!isManager(session)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String managerId = getManagerId(session);
                int taskId = Integer.parseInt(value(request, "id"));
                String status = value(request, "status");
                String ratingText = value(request, "managerRating");
                String remarks = value(request, "managerRemarks");

                if (!taskDAO.isCreatedByManager(taskId, managerId)) {
                    redirect(request, response,
                        "You cannot review this task.");
                    return;
                }

                int rating;

                try {
                    rating = Integer.parseInt(ratingText);
                } catch (NumberFormatException e) {
                    redirect(request, response,
                        "Please select a valid rating.");
                    return;
                }

                boolean reviewed = taskDAO.reviewTask(
                    taskId, managerId, status, rating, remarks
                );

                redirect(request, response,
                    reviewed
                        ? "Task reviewed successfully."
                        : "Task review failed. Check status and rating.");
                return;
            }

            // MANAGER: DELETE ONE EMPLOYEE'S TASK RECORD
            if ("delete".equals(action) && isManager(session)) {

                String managerId = getManagerId(session);
                int taskId = Integer.parseInt(value(request, "id"));

                boolean deleted =
                    taskDAO.deleteTaskByManager(taskId, managerId);

                redirect(request, response,
                    deleted
                        ? "Task deleted successfully."
                        : "Task could not be deleted.");
                return;
            }

            // EMPLOYEE: SUBMIT MULTIPLE PDF WORK PROOFS
            if ("submitProof".equals(action)
                    || "submitWork".equals(action)) {

                if (!isEmployee(session)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String employeeId = getEmployeeId(session);
                int taskId = Integer.parseInt(value(request, "id"));

                if (!taskDAO.isAssignedToEmployee(taskId, employeeId)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String comment = value(request, "employeeComment");
                StringBuilder proofFiles = new StringBuilder();

                try {
                    for (Part part : request.getParts()) {

                        if ("workProofFile".equals(part.getName())
                                && part.getSize() > 0) {

                            String savedFile = saveProofUpload(part);

                            if (savedFile != null) {
                                if (proofFiles.length() > 0) {
                                    proofFiles.append("|");
                                }

                                proofFiles.append(savedFile);
                            }
                        }
                    }

                } catch (ServletException e) {
                    response.sendRedirect(
                        request.getContextPath()
                            + "/tasks?message="
                            + URLEncoder.encode(
                                e.getMessage(), StandardCharsets.UTF_8
                            )
                    );
                    return;
                }

                String proofFile = proofFiles.length() > 0
                    ? proofFiles.toString()
                    : null;

                boolean submitted = taskDAO.submitWork(
                    taskId, employeeId, proofFile, comment
                );

                response.sendRedirect(
                    request.getContextPath()
                        + "/tasks?message="
                        + URLEncoder.encode(
                            submitted
                                ? "Work proof submitted successfully."
                                : "Work proof submission failed.",
                            StandardCharsets.UTF_8
                        )
                );
                return;
            }

            // EMPLOYEE: UPDATE TASK PROGRESS
            if ("progress".equals(action)
                    || "updateProgress".equals(action)) {

                if (!isEmployee(session)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String employeeId = getEmployeeId(session);
                int taskId = Integer.parseInt(value(request, "id"));

                if (!taskDAO.isAssignedToEmployee(taskId, employeeId)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                String status = value(request, "status");
                String comment = value(request, "employeeComment");

                boolean updated = taskDAO.updateTaskProgress(
                    taskId, employeeId, status, comment
                );

                response.sendRedirect(
                    request.getContextPath()
                        + "/tasks?message="
                        + URLEncoder.encode(
                            updated
                                ? "Task progress updated."
                                : "Task progress update failed.",
                            StandardCharsets.UTF_8
                        )
                );
                return;
            }

            // ADMIN: DELETE TASK
            if ("adminDelete".equals(action)
                    || ("delete".equals(action) && isAdmin(session))) {

                if (!isAdmin(session)) {
                    response.sendError(HttpServletResponse.SC_FORBIDDEN);
                    return;
                }

                int taskId = Integer.parseInt(value(request, "id"));
                boolean deleted = taskDAO.deleteTask(taskId);

                response.sendRedirect(
                    request.getContextPath()
                        + "/admin_dashbaord.jsp?message="
                        + URLEncoder.encode(
                            deleted
                                ? "Task deleted successfully."
                                : "Task deletion failed.",
                            StandardCharsets.UTF_8
                        )
                );
                return;
            }

            response.sendError(
                HttpServletResponse.SC_BAD_REQUEST,
                "Invalid task action."
            );

        } catch (NumberFormatException e) {
            redirect(request, response,
                "Invalid task ID or input value.");

        } catch (Exception e) {
            e.printStackTrace();

            redirect(request, response,
                "An error occurred while processing the task.");
        }
    }
}
