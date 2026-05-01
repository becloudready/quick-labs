# Linux Administration Skills Assessment Lab

## Overview

This repository contains resources for assessing Linux administration skills, covering both theoretical knowledge and practical hands-on abilities. It is designed to help interviewers and trainers evaluate candidates or students on various aspects of Linux system management.

The lab is structured into different skill domains, primarily:
1.  **Core Linux & Intermediate Skills:** User management, file permissions, package management, basic scripting, service management.
2.  **Networking:** DNS configuration, hostname resolution, port listening, firewall rules, interface inspection.
3.  **Storage Management:** Partitioning, filesystems (XFS, ext4), LVM (PVs, VGs, LVs, expansion), mounting.

For each domain, this repository provides:
*   **Candidate Task Assignments:** Problem-oriented tasks for candidates to solve, typically presented in a `README.md` format within respective directories (or as shown in conversation history). These define the "desired state" the candidate should achieve.
*   **Ansible Validation Playbooks:** Ansible playbooks designed to run against the candidate's test environment *after* they have attempted the tasks. These playbooks check if the system's configuration matches the desired state outlined in the assignments.
*   **(Previously Discussed) Web Application for Theory Questions:** A simple Flask-based web application to serve multiple-choice and short-answer theory questions. (Code for this would be in a separate directory like `theory_test_app/`).

## Purpose

The primary goal is to provide a structured and partially automatable way to:
*   Present realistic Linux administration challenges.
*   Objectively verify the outcomes of practical tasks.
*   Cover a range of skills from intermediate to more advanced topics.

## Structure (Conceptual)

While the content was developed iteratively, a good repository structure might be:
