


package model;

import java.sql.Date;
import java.sql.Timestamp;

public class Task {

    private int id;
    private String taskGroupId;

    private String taskTitle;
    private String description;
    private String assignedTo;
    private String createdBy;
    private String createdByName;
    private String department;
    private String priority;

    private Date startDate;
    private Date dueDate;

    private String status;
    private String employeeComment;

    private Timestamp createdAt;
    private Timestamp updatedAt;

    private String instructionFile;
    private String workProofFile;

    private Integer managerRating;
    private String managerRemarks;
    private String reviewedBy;
    private Timestamp reviewedAt;

    public Task() {
    }

    // Task ID
    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    // Shared ID for tasks assigned together
    public String getTaskGroupId() {
        return taskGroupId;
    }

    public void setTaskGroupId(String taskGroupId) {
        this.taskGroupId = taskGroupId;
    }

    // Task title
    public String getTaskTitle() {
        return taskTitle;
    }

    public void setTaskTitle(String taskTitle) {
        this.taskTitle = taskTitle;
    }

    // Task description
    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    // Employee assigned to this task
    public String getAssignedTo() {
        return assignedTo;
    }

    public void setAssignedTo(String assignedTo) {
        this.assignedTo = assignedTo;
    }

    // Manager who created the task
    public String getCreatedBy() {
        return createdBy;
    }

    public void setCreatedBy(String createdBy) {
        this.createdBy = createdBy;
    }

    public String getCreatedByName() {
        return createdByName;
    }

    public void setCreatedByName(String createdByName) {
        this.createdByName = createdByName;
    }

    // Department
    public String getDepartment() {
        return department;
    }

    public void setDepartment(String department) {
        this.department = department;
    }

    // Priority
    public String getPriority() {
        return priority;
    }

    public void setPriority(String priority) {
        this.priority = priority;
    }

    // Start date
    public Date getStartDate() {
        return startDate;
    }

    public void setStartDate(Date startDate) {
        this.startDate = startDate;
    }

    // Due date
    public Date getDueDate() {
        return dueDate;
    }

    public void setDueDate(Date dueDate) {
        this.dueDate = dueDate;
    }

    // Task status
    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    // Employee comment
    public String getEmployeeComment() {
        return employeeComment;
    }

    public void setEmployeeComment(String employeeComment) {
        this.employeeComment = employeeComment;
    }

    // Created timestamp
    public Timestamp getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Timestamp createdAt) {
        this.createdAt = createdAt;
    }

    // Updated timestamp
    public Timestamp getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Timestamp updatedAt) {
        this.updatedAt = updatedAt;
    }

    // Manager's instruction file
    public String getInstructionFile() {
        return instructionFile;
    }

    public void setInstructionFile(String instructionFile) {
        this.instructionFile = instructionFile;
    }

    // Employee's work proof
    public String getWorkProofFile() {
        return workProofFile;
    }

    public void setWorkProofFile(String workProofFile) {
        this.workProofFile = workProofFile;
    }

    // Manager rating for this employee's task
    public Integer getManagerRating() {
        return managerRating;
    }

    public void setManagerRating(Integer managerRating) {
        this.managerRating = managerRating;
    }

    // Manager review remarks
    public String getManagerRemarks() {
        return managerRemarks;
    }

    public void setManagerRemarks(String managerRemarks) {
        this.managerRemarks = managerRemarks;
    }

    // Manager who reviewed the task
    public String getReviewedBy() {
        return reviewedBy;
    }

    public void setReviewedBy(String reviewedBy) {
        this.reviewedBy = reviewedBy;
    }

    // Review timestamp
    public Timestamp getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(Timestamp reviewedAt) {
        this.reviewedAt = reviewedAt;
    }
}
