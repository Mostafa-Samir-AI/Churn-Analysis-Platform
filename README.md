# 📊 Customer Churn Intelligence Platform

## 🚀 Overview

This project is an **end-to-end data science platform** designed to analyze, predict, and explain customer churn behavior.

Instead of building a simple machine learning model, this system simulates a **real-world production environment** by integrating:

* Data analysis (EDA)
* Feature engineering
* Machine learning
* OLTP & OLAP data systems
* API deployment
* Dashboard visualization
* Retrieval-Augmented Generation (RAG) assistant

---

## 🎯 Objectives

* Predict which customers are likely to churn
* Understand **why** customers churn
* Provide **actionable business insights**
* Simulate a **real data platform architecture**
* Deliver insights through APIs and dashboards

---

## 🧠 Key Features

### 🔍 1. Exploratory Data Analysis (EDA)

* Deep analysis of customer behavior
* Identification of churn patterns
* Statistical and visual insights

### ⚙️ 2. Feature Engineering

* Creation of meaningful features such as:

  * Customer tenure groups
  * Engagement metrics
  * Service usage indicators

### 🤖 3. Machine Learning Models

* Logistic Regression
* Random Forest
* Model evaluation using:

  * Recall
  * F1 Score
  * ROC-AUC

### 🧠 4. Explainability

* Feature importance analysis
* Understanding key churn drivers

### 🗄️ 5. Data Architecture

#### OLTP (Operational Database)

* Simulates real-world transactional system
* Normalized schema (customers, services, payments)

#### OLAP (Data Warehouse)

* Star schema design
* Optimized for analytics and reporting

### ⚡ 6. API Layer (FastAPI)

* Exposes model predictions
* Provides business insights endpoints

### 📊 7. Dashboard

* Interactive visualization (Streamlit or Power BI)
* Displays:

  * Churn rate
  * Customer segments
  * Risk analysis

### 🤖 8. Mini RAG System (Bonus)

* Natural language assistant for business insights
* Answers questions like:

  * “Why are customers churning?”
  * “Which customers are at risk?”

---

## 🏗️ Project Structure

```
churn-platform/
│
├── data/
│   ├── raw/                # Original dataset
│   ├── processed/          # Cleaned & transformed data
│
├── notebooks/
│   ├── 01_eda.ipynb
│   ├── 02_feature_engineering.ipynb
│   ├── 03_modeling.ipynb
│   └── 04_business_insights.ipynb
│
├── src/
│   ├── config.py
│   │
│   ├── data/
│   │   ├── load_data.py
│   │   └── preprocess.py
│   │
│   ├── features/
│   │   └── build_features.py
│   │
│   ├── models/
│   │   ├── train.py
│   │   ├── predict.py
│   │   └── evaluate.py
│   │
│   └── utils/
│       └── helpers.py
│
├── api/
│   └── main.py             # FastAPI application
│
├── dashboard/
│   └── app.py              # Streamlit dashboard
│
├── sql/
│   ├── oltp_schema.sql     # Transactional DB schema
│   ├── olap_schema.sql     # Data warehouse schema
│   └── queries.sql         # Analytical queries
│
├── docker/
│   ├── Dockerfile.api
│   ├── Dockerfile.dashboard
│   └── docker-compose.yml
│
├── requirements.txt
├── README.md
```

---

## 🔄 System Architecture

```
Raw Data (CSV)
      ↓
OLTP Database (PostgreSQL)
      ↓
ETL Pipeline (Python)
      ↓
Data Warehouse (OLAP - Star Schema)
      ↓
 ┌────────────┬────────────┬────────────┐
 ↓            ↓            ↓
Dashboard     ML Model     API
(Streamlit)   (Churn)      (FastAPI)
```

---

## 🧪 Technologies Used

* Python (Pandas, NumPy, Scikit-learn)
* SQL (PostgreSQL)
* Data Visualization (Seaborn, Matplotlib)
* FastAPI (API layer)
* Streamlit / Power BI (Dashboard)
* Docker (Containerization)
* FAISS + Embeddings (Mini RAG)

---

## 📈 Key Business Insights (Example)

* Customers with **month-to-month contracts** have the highest churn rate
* **Short-tenure customers** are more likely to leave
* Higher **monthly charges** increase churn probability
* Lack of **support services** leads to higher churn

---

## 💡 Business Recommendations

* Offer incentives for long-term contracts
* Improve onboarding experience for new customers
* Target high-risk customers with retention campaigns
* Enhance customer support services

---

## 🚀 How to Run

### 1. Clone the repository

```
git clone <repo_url>
cd churn-platform
```

### 2. Install dependencies

```
pip install -r requirements.txt
```

### 3. Run API

```
uvicorn api.main:app --reload
```

### 4. Run Dashboard

```
streamlit run dashboard/app.py
```

### 5. Run with Docker

```
docker-compose up --build
```

---

## 🧠 What Makes This Project Special

* End-to-end data pipeline (not just a notebook)
* Combines **ML + Data Engineering + Backend**
* Includes **OLTP & OLAP systems**
* Production-ready structure
* Business-focused insights
* AI-powered assistant (RAG)

---

## 👨‍💻 Author

**Mostafa Samir**
Data Scientist | AI Engineer

