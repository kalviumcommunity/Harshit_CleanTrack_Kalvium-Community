CleanTrack — Product Requirements Document (PRD)
Document Information

Field
Details
Product Name
CleanTrack
Version
1.1
Status
Final
Date
September 26, 2026
Team
CacheCrew
Primary Users
Supervisor, Worker
Stakeholder
Admin


1. Product Overview
CleanTrack is a hospital housekeeping management system that digitizes task assignment, verification, and workforce allocation across hospital wards.
Instead of relying on verbal instructions, supervisors assign cleaning tasks digitally to workers within their ward. Workers complete assigned tasks, supervisors verify the work, and administrators oversee ward allocation, suspensions, and compliance reporting.
The system maintains a complete history of every task assignment—even when a task is reassigned to another worker—allowing accurate monthly compliance reporting and workforce accountability.

2. Problem Statement
Current Situation
Ward supervisors/managers are responsible for assigning, tracking, and verifying hospital housekeeping tasks across their wards, but currently rely heavily on ad-hoc, manual coordination methods such as verbal instructions, paper logs, and informal messaging. Supervisors distribute cleaning tasks manually to housekeeping staff/workers without a central system to track worker availability or real-time task status. As a result, cleaning activities are loosely monitored, and task verification depends on irregular physical walkthroughs.
Key Pain Points
Manual & Verbal Task Assignments: Lack of a centralized digital log leads to miscommunication, missed tasks, and unassigned ward areas.
No Structured Verification Process: Supervisors lack standard, timed verification workflows, causing delay in feedback and inconsistent cleaning quality.
Invisibility of Workforce Availability: Supervisors cannot easily determine which workers are idle or overloaded, leading to inefficient task distribution.
Loss of Reassignment History & Accountability: When tasks are reassigned or incomplete, previous assignment attempts are overwritten, eliminating audit trails for performance issues.
Inaccurate Compliance Tracking: Compiling monthly compliance reports requires manual consolidation, leading to delayed reporting and data errors across wards.
Quantified Impact
Baseline measurements are required before these impacts can be quantified. The following metrics will be collected during the baseline measurement period:
Efficiency Loss: Supervisors spend up to 25% of shift time manually assigning tasks and locating available workers. (Baseline note: To be measured during 2-week pre-pilot observation period)
Verification Delays: Approximately 15% of completed cleaning tasks remain unverified for over 24 hours due to lack of automated alerts. (Baseline note: To be measured during 2-week pre-pilot observation period)
Audit Failure Rate: An estimated 10% of reassigned or failed tasks are omitted from monthly compliance records owing to missing history. (Baseline note: To be measured during 2-week pre-pilot observation period)
Reporting Overhead: Compiling ward compliance reports manually requires 8 hours per ward every month. (Baseline note: To be measured during 2-week pre-pilot observation period)
Business Impact
Unstructured housekeeping management compromises hospital hygiene standards and increases operational risk. Potential business impacts requiring stakeholder validation include delayed bed turnover, lower patient satisfaction scores, and heightened infection risk in critical wards. Furthermore, without accurate assignment records, administrators face challenges evaluating worker productivity, managing suspensions fairly, and substantiating compliance or operational records during hospital accreditation audits.
Success Criteria
During the defined MVP pilot measurement period approved by stakeholders across target wards:
Verification Timeliness: ≥90% of completed tasks verified (or auto-verified) within 24 hours during the 30-day MVP pilot timeline.
Task Allocation Rule: 100% adherence to single active task assignment per worker throughout the 30-day MVP pilot timeline.
Ward Governance: 100% successful supervisor and worker ward assignments prior to pilot launch.
Reporting Coverage: Monthly compliance reports generated and available for 100% of target wards within 2 business days of month-end.
Data Still Needed
The following data values must be validated with the relevant business, operations, and analytics stakeholders before the impact claims are treated as measured facts:
Baseline measurement of current average task verification turnaround time per ward.
Historical rate of missed task deadlines and worker suspensions to calibrate initial thresholds.
Exact hours currently spent by supervisors and admins compiling monthly compliance reports.
Specific target wards selected for initial MVP pilot rollout and defined baseline measurement period duration.

3. Goals & Objectives
Primary Goal
Digitize housekeeping task management while ensuring accountability through structured assignment, verification, suspension handling, and compliance reporting.
Objectives
Digitize task assignment.
Ensure one active task per worker.
Enable supervisors to verify completed work.
Preserve assignment history for reporting.
Improve ward-level visibility.
Generate accurate monthly compliance reports.

4. Target Users
Admin
Role: Hospital operations administrator.
Needs
Assign supervisors to wards.
Assign workers to wards.
View pending registrations.
Monitor suspended workers.
Track compliance across wards.

Supervisor
Role: Ward manager.
Needs
Assign tasks.
Find available workers.
Verify completed tasks.
Reassign tasks when necessary.
Monitor worker availability.
Business Rule: Each supervisor manages one ward.

Worker
Role: Housekeeping staff.
Needs
Receive assigned work.
View task instructions.
Complete tasks.
Receive supervisor feedback when work is reassigned.
Business Rule: Each worker belongs to one ward.

5. User Stories

Admin Stories

ID
Title
User Story
A01
Assign Ward
As an admin, I want to assign registered users to wards, so that the hospital workforce structure remains organized and operational.
A02
View Suspensions
As an admin, I want to monitor suspended workers, so that I can oversee workforce availability and handle account reinstatements.
A03
View Compliance
As an admin, I want monthly ward-wise compliance reports, so that I can monitor overall hospital cleaning performance and standards.


Supervisor Stories

ID
Title
User Story
S01
Find Available Workers
As a supervisor, I want to see workers without active tasks, so that I can assign work efficiently without overloading staff.
S02
Assign Task
As a supervisor, I want to assign cleaning tasks to workers, so that housekeeping work begins immediately and wards stay clean.
S03
Verify Work
As a supervisor, I want to verify completed work, so that finished tasks meet hospital hygiene standards.
S04
Reassign Same Worker
As a supervisor, I want to resend a task with feedback, so that the worker can correct mistakes and complete the job properly.
S05
Reassign Another Worker
As a supervisor, I want to assign the same task to another available worker when the previous worker fails, so that the task can be completed without unnecessary delay.


Worker Stories

ID
Title
User Story
W01
Receive Task
As a worker, I want to receive a clear task with instructions, so that I understand what work I need to complete and how it should be performed.
W02
Complete Task
As a worker, I want to mark my assigned work as completed, so that my supervisor can review and verify the completed task.
W03
Receive Feedback
As a worker, I want to receive supervisor feedback when my task is reassigned, so that I understand what needs to be corrected before completing the task again.
W04
Suspension Notice
As a worker whose account has been suspended, I want to know why I cannot access the application, so that I understand the reason for the suspension and know whom to contact for assistance.


6. Functional Requirements

6.1 User Registration

ID
Requirement
R01
Supervisors must be able to register.
R02
Workers must be able to register.
R03
New registrations remain in Pending until assigned by Admin.
R04
Employee IDs must follow the defined format.


Employee ID Format
Role
Format
Supervisor
SUP-001
Worker
WRK-001


6.2 Ward Management

ID
Requirement
W01
Admin assigns one supervisor to one ward.
W02
Admin assigns multiple workers to a ward.
W03
Workers belong to only one ward.
W04
Admin can create a new ward if no suitable ward exists.


6.3 Task Management
Task Creation
Every task contains:
Task title
Task description
Deadline
The task belongs to the ward.
Task Assignment Rules

ID
Requirement
T01
A worker can have only one active assignment.
T02
Supervisors assign tasks only within their ward.
T03
Workers without active assignments appear as Available.


6.4 Task Completion

ID
Requirement
C01
Workers can mark assignments as completed.
C02
Proof upload is not required.
C03
Completed work enters Pending Verification.


6.5 Verification

ID
Requirement
V01
Supervisors verify completed assignments.
V02
Supervisors have 24 hours to verify.
V03
Unverified assignments automatically become Auto Verified after 24 hours.


6.6 Reassignment

A supervisor has two reassignment options.
Reassign to the Same Worker
When the same worker receives the task again:
Original task description remains visible.
The supervisor must provide mandatory feedback.
A new Task Assignment record is created.
Reassign to Another Worker
If the assigned worker fails:
The previous assignment remains unchanged.
Worker becomes suspended.
Supervisor selects another available worker.
A new Task Assignment record is created.
The previous assignment history is never overwritten.

6.7 Suspension Rules

ID
Requirement
SU01
Missing a deadline results in suspension.
SU02
Exceeding three attempts results in suspension.
SU03
Suspended workers cannot log into the application.
SU04
Suspended workers see a Suspension Screen upon login.


7. Business Rules
One worker can have only one active task.
Missing a deadline immediately marks the assignment Not Completed.
Three failed attempts immediately mark the assignment Not Completed.
Suspended workers cannot access the application.
Supervisors can immediately assign the same task to another available worker after failure.
Same-worker reassignment always requires mandatory feedback.
Every reassignment creates a new Task Assignment record.

8. Status Definitions
Worker Status

Status
Meaning
Pending
Awaiting ward assignment
Available
No active assignment
Busy
Currently assigned work
Suspended
Login blocked

Supervisor Status

Status
Meaning
Pending
Awaiting ward assignment
Assigned
Assigned to a ward

Task Status

Status
Meaning
Open
Task exists and can receive assignments
Closed
Task completed successfully


Task Assignment Status
Status
Meaning
Completed
Worker finished work
Pending Verification
Awaiting supervisor review
Verified
Approved by supervisor
Auto Verified
Automatically approved
Not Completed
Failed assignment


9. Notification Requirements
Worker
New task assigned.
Same task reassigned with supervisor feedback.
Supervisor
Completed task awaiting verification.
Admin
New pending registrations.
Task auto verified.
Task not completed due to missed deadline.
Worker suspended.



10. MVP Scope
In Scope
Worker registration
Supervisor registration
Ward assignment
Task creation
Single active task per worker
Task completion
Supervisor verification
Auto verification
Reassignment to same worker
Reassignment to another worker
Worker suspension
Monthly compliance reporting
Out of Scope
Attendance tracking
Payroll
Equipment management
Inventory management
GPS tracking
QR/NFC
AI verification
Photo proof
Multi-hospital management

11. Success Metrics (KPIs)

11.1 Operational KPIs

Metric Name
Measurement Method
Numeric Target
Timeline
Tasks verified within 24 hours
(Verified tasks ≤24h ÷ Total completed tasks) × 100
≥90%
30-Day MVP Pilot
Single active task compliance
(Workers with ≤1 active task ÷ Total active workers) × 100
100%
30-Day MVP Pilot
Successful ward assignments
(Properly mapped staff ÷ Total onboarded staff) × 100
100%
Pre-Pilot Launch


11.2 Compliance KPIs

Metric Name
Measurement Method
Numeric Target
Timeline
Ward completion rate
(Completed assignments ÷ Total assigned tasks) × 100 per ward
≥95% per ward
Monthly
Missed assignments rate
(Not Completed assignments ÷ Total assigned tasks) × 100 per ward
≤5% per ward
Monthly
Auto verification rate
(Auto Verified assignments ÷ Total verified tasks) × 100 per ward
≤10% per ward
Monthly
Worker suspension rate
(Suspended workers ÷ Total active workers) × 100 per ward
≤2% per ward
Monthly


Note: Monthly compliance reports are generated directly from Task Assignment records, ensuring full visibility into reassigned and failed tasks without data loss.

12. UX Flow
Complete System Flow

START
   ↓
User Registration
   ↓
Pending Account
   ↓
Admin Assigns Ward
   ↓
Role Dashboard


Worker Flow

Worker Dashboard
      ↓
View Current Assignment
      ↓
Complete Assignment
      ↓
Pending Verification


Supervisor Flow

Supervisor Dashboard
      ↓
Find Available Worker
      ↓
Create Task
      ↓
Create Assignment
      ↓
Worker Completes
      ↓
Review
      ├── Verify
      ├── Reassign Same Worker
      └── Reassign Another Worker


Suspension Flow

Deadline Missed
        OR
Maximum Attempts Exceeded
        ↓
Worker Suspended
        ↓
Login Attempt
        ↓
Suspension Screen



13. Logical Database Design (Firebase Cloud Firestore)

The CleanTrack backend utilizes Firebase Cloud Firestore, a document-oriented NoSQL database. The database architecture relies on top-level collections, subcollections, document references, and strategically denormalized fields to optimize reading efficiency, enforce transactional integrity, and maintain a historical audit log.

13.1 `users` Collection ( Path: `users/{userId}` )

Field Name
Data Type
Description & Purpose
userId
string
Document ID (matches Firebase Auth UID)
name
string
Full name of the user
employeeId
string
Formatted employee identifier (e.g. SUP-001, WRK-001)
email
string
Primary email address
role
string
User role enum: "Admin" | "Supervisor" | "Worker"
wardRef
reference
Firestore reference pointer to `wards/{wardId}`
wardId
string
Denormalized string ID of assigned ward for query filtering
status
string
User status enum: "Pending" | "Available" | "Busy" | "Suspended" | "Assigned"
activeAssignmentId
string | null
Document ID of current active assignment (null if available)
createdAt
timestamp
Account registration timestamp


13.2 `wards` Collection ( Path: `wards/{wardId}` )

Field Name
Data Type
Description & Purpose
wardId
string
Auto-generated Document ID
name
string
Hospital ward name (e.g. Ward A, ICU)
supervisorRef
reference
Pointer reference to `users/{supervisorUserId}`
supervisorId
string
Denormalized string ID of assigned supervisor
createdAt
timestamp
Ward creation timestamp


13.3 `tasks` Collection ( Path: `tasks/{taskId}`) 

Represents the core task definition created by a supervisor.

Field Name
Data Type
Description & Purpose
taskId
string
Auto-generated Document ID
wardRef
reference
Pointer reference to `wards/{wardId}`
wardId
string
Denormalized ward string ID for query index filtering
createdByRef
reference
Pointer reference to assigning `users/{supervisorUserId}`
title
string
Title of the cleaning task
description
string
Detailed task instructions
createdAt
timestamp
Creation timestamp
status
string
Lifecycle status: "Open" | "Closed"
currentAssignmentId
string
Document ID of latest assignment attempt document


13.4 `taskAssignments` Collection ( Path: `taskAssignments/{assignmentId}` )  

Stored as a top-level collection (or subcollection under `tasks/{taskId}/assignments/{assignmentId}`). Every task assignment attempt creates an immutable document to preserve full historical tracking.


Field Name
Data Type
Description & Purpose
assignmentId
string
Auto-generated Document ID
taskRef
reference
Reference pointer to `tasks/{taskId}`
taskId
string
Denormalized parent task document ID
workerRef
reference
Reference pointer to `users/{workerUserId}`
workerId
string
Denormalized worker user ID
supervisorRef
reference
Reference pointer to `users/{supervisorUserId}`
wardId
string
Denormalized ward string ID (essential for ward compliance queries)
assignmentNumber
number
Attempt sequence number for parent task (1, 2, 3...)
supervisorFeedback
string | null
Mandatory feedback on same-worker reassignment
attempts
number
Total attempt count accumulated
deadline
timestamp
Timestamp when task assignment is due
assignedAt
timestamp
Timestamp when assignment was created
completedAt
timestamp | null
Timestamp when worker marked task completed
verifiedAt
timestamp | null
Timestamp when supervisor or auto-verification approved
status
string
Assignment status enum: "Completed" | "Pending Verification" | "Verified" | "Auto Verified" | "Not Completed"


13.5 Monthly Compliance Reporting Flow

Monthly compliance metrics are queried directly from the `taskAssignments` collection using `wardId` and `assignedAt` range filters. Because every reassignment creates a distinct document in `taskAssignments`, failed attempts ("Not Completed") are preserved alongside successful ones ("Verified" / "Auto Verified"), guaranteeing accurate audit trails and preventing data overwrites.

Admin
 │
 ├── Wards
 │      │
 │      └── Supervisor
 │              │
 │              └── Workers
 │                      │
 │                      └── Task Assignments
 │
 └── Monthly Reports


Task relationship:

Task (1)
   │
   ├── Assignment 1 → Worker A
   ├── Assignment 2 → Worker B
   └── Assignment 3 → Worker A


This preserves every assignment attempt.

14. Monthly Compliance Report

The report is generated from Task Assignment records.
Example
Ward A (95.8%)

Metric
Count
Tasks assigned
120
Completed
115
Missed
5


Ward B (99%)
Metric
Count
Tasks assigned
100
Completed
99
Missed
1

Completion Rate Formula
Completed AssignmentsTotal Assignments100Because every reassignment creates a new Task Assignment record, failed assignments remain visible instead of being overwritten.

15. Risks & Assumptions
The following risk register and assumptions outline potential operational, technical, and governance risks along with their mitigation plans and validation owners.

ID
Risk / Unconfirmed Assumption
Likelihood
Impact
Mitigation Plan
Validation Owner
RISK-01
Unique Employee ID assumption invalid across third-party/contract staff
Medium
High
Enforce system-generated unique ID mapping during onboarding
HR / Operations Admin
RISK-02
Workers shared across multiple wards during shift shortages
High
Medium
Allow Admin temporary ward transfer permissions in MVP phase 2
Ward Operations Lead
RISK-03
Single supervisor per ward bottleneck during shift overlaps/absences
High
High
Designate backup Admin override for urgent verification
Hospital Admin
RISK-04
Single active task restriction delays emergency cleaning requests
Medium
High
Implement supervisor override to pause/cancel current active task
Product Manager
RISK-05
Auto-verification at 24 hours lowers quality accountability
Medium
Medium
Flag auto-verified tasks separately on Admin compliance dashboard
Quality Assurance Lead
RISK-06
Suspension on single missed deadline causes artificial worker shortage
High
High
Provide 15-minute grace period before triggering automated suspension
Operations Lead
RISK-07
Low digital literacy among housekeeping staff delaying adoption
High
High
Conduct localized visual training workshops and simple UI design
Change Management
RISK-08
Inconsistent Wi-Fi/cellular connectivity in hospital basement areas
High
Critical
Implement offline task state caching and sync on reconnection
Technical Lead
RISK-09
Lack of photo proof leads to dispute between supervisor and worker
Medium
Medium
Include photo upload requirement in post-MVP scope
Product Manager
RISK-10
Supervisors default to same-worker reassignment repeatedly
Medium
Low
Limit max same-worker attempts to 3 before auto-escalation
Operations Admin
RISK-11
Admin delay in approving pending registrations halts staffing
Medium
Medium
Send automated email reminders for pending approvals >12 hours
System Admin
RISK-12
Data loss during compliance reporting due to schema mismatch
Low
High
Decouple Task entity from Task Assignment history table
Database Architect
RISK-13
Push notifications fail on worker personal mobile devices
High
Medium
Fallback to SMS alert backup for critical task assignments
Technical Lead
RISK-14
Resistance to strict automated suspension policies from labor union
Medium
High
Engage stakeholders early; enable supervisor review option
HR Lead
RISK-15
Inaccurate baseline measurements distort pilot success evaluation
Medium
Medium
Establish standardized 2-week manual baseline logging prior to launch
Analytics Lead


Validation Checklist

ID
Validation Item
Status
VAL-01
Confirm employee ID format compatibility with contract workers
Pending Review
VAL-02
Validate offline sync reliability in basement ward locations
In Progress
VAL-03
Obtain HR agreement on automated worker suspension rules
Pending Approval


16. Edge Cases

ID
Edge Case
Expected Behavior
E01
Worker registers
Account remains Pending
E02
Supervisor registers
Account remains Pending
E03
Worker has active assignment
Cannot receive another assignment
E04
Deadline missed
Assignment becomes Not Completed and worker is suspended
E05
Three attempts exceeded
Assignment becomes Not Completed and worker is suspended
E06
Supervisor takes no action for 24 hours
Assignment becomes Auto Verified
E07
Task reassigned to same worker
New assignment with feedback
E08
Task reassigned to another worker
New assignment while previous history remains
E09
Suspended worker logs in
Suspension screen appears


17. Acceptance Criteria

ID
Acceptance Criteria
AC01
Supervisors and workers can register successfully.
AC02
Admin can assign wards.
AC03
One supervisor manages one ward.
AC04
Workers belong to one ward.
AC05
Workers receive only one active assignment.
AC06
Supervisors can create tasks with descriptions.
AC07
Workers can complete assignments.
AC08
Completed assignments enter Pending Verification.
AC09
Supervisors can verify assignments.
AC10
Auto Verification occurs after 24 hours.
AC11
Same-worker reassignment creates a new assignment with feedback.
AC12
Another-worker reassignment creates a new assignment while preserving previous history.
AC13
Missed deadlines create Not Completed assignments.
AC14
Three failed attempts create Not Completed assignments.
AC15
Suspended workers see the Suspension Screen instead of the dashboard.
AC16
Admin receives notifications for Auto Verification, missed deadlines, and suspensions.
AC17
Monthly compliance reports correctly count every Task Assignment per ward.

Final System Workflow
START
   │
User Registration
   │
Pending Account
   │
Admin Assigns Ward
   │
Supervisor Creates Task
(Task + Description)
   │
Assignment Created
   │
Worker Completes
   │
Pending Verification
   │
 ┌─────────────┬─────────────┐
 │             │             │
Verify     Auto Verify   Reassign
 │                           │
 │                     Same Worker
 │                           │
 │                     Feedback Added
 │                           │
 │                     New Assignment
 │
 └────────── Another Worker ──────────┐
                                      │
                            Previous Assignment Preserved
                                      │
                           New Assignment Created
                                      │
                           Monthly Report Updated

