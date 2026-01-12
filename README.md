**Executive Summary**

I designed and implemented a production style news recommendation ranking system that prioritizes
content using real user behavior data from MIND Small datasets. I built a scalable SQL data engineering pipeline to generate machine
learning ready features and trained learning to rank models in Python to improve content ordering. The
final model outperformed popularity based and behavioral (co-click) baselines using industry standard ranking
metrics(NDCG@10), demonstrating measurable gains in recommendation quality.

**Project Overview**
This project focuses on the ranking portion of a recommendation system. Essentially taking all of the recommended news articles and ranking them in order of which article the user should see first to maximize engagements.

The system integrates 

- data preperation, cleaning, and organizing within SQL
- Machine learning ranking models in python
- Quantitative model evaluation with offline ranking metrics

This project mirrors real world recommendation system models created with machine learning among large media companies


**Business Problem**
When users are presented with many content options, ranking quality directly affects:

- Click-through rate (CTR)

- User engagement

- Retention rates and times

This project demonstrates how machine learning can replace simple unpersonalized lists (e.g., “most popular articles”) with models that learn from historical user behavior to make better individualized ranking decisions.

**Data**
Dataset: Microsoft News Dataset (MIND – Small)

Content:

- News metadata (category, subcategory, title, abstract)
- User behavior logs (impressions, clicks, reading history)

-  Raw data is anonymized and publicly available. Data files used are not included in the repository for download.

Files used:
- 
- news_train.tsv
- behaviors_train.tsv
- news_dev.tsv
- behaviors_dev.tsv

**SQL Data Engineering**

Implemented in SQL Server, the pipeline:

- Loads raw TSV files
- Parses impressions and click labels
- Normalizes data into relational tables
- Engineers features including:

-Global article CTR
-Title and abstract length
-Content category and subcategory

- Outputs ML-ready tables:

-ml_train_shown
-ml_dev_shown

These tables are optimized for learning-to-rank models and exported to Python.

**Machine Learning with Python**

Implemented in Jupyter Notebook using Python 3.6.

Models trained:

- LightGBM Ranker (LambdaRank)
- XGBoost Ranker

Baselines:

- Global popularity (CTR)
- Co-click behavioral score

Evaluation metric:

- nDCG@10 (Normalized Discounted Cumulative Gain)

**Results**

nDCG@10 (XGBoost ranker): 0.3884337122857202
nDCG@10 (LightGBM ranker): 0.4443029032056575
nDCG@10 (coclick_score): 0.38460111697209587
nDCG@10 (global_ctr): 0.2991319013358326

Key result:
The LightGBM and XGBoost ranking models outperformed both popularity-based and behavioral baselines, showing the effectiveness of supervised learning-to-rank approaches. The LightGBM model was the highest performing emphasizing the importance of testing different ML models against each other and the baselines.

**Business Interpretation and Application**

Rather than simply ranking recomendations based on popularity (global_ctr), or based on articles frequently clicked on next based on the users current article(co_click). My models learns patterns from historical user interactions to predict which articles the user is most likely to click and ranks them in order. This leads to a more effective ordering system and greater customer engagement compared to the original models of global_ctr and co_click scores.

**How To Run**

1. Download the MIND small dataset from the official MIND website
2. Update the file path names in SQLQuery1.sql 
3. Run the SQL query to load the ML usable tables 
4. Download the final two tables as csv files
5. Run the Jupyter notebook(ipynb) file end-to-end

**Technical Tools and Libraries**

- SQL Server
- Python 3.6
- Pandas
- NumPy
- Scikit-learn
- LightGBM
- XGBoost

****Limitations***

- offline evaluation only (no live A/B testing)
- Limited dataset size(due to python server limitations

**Next Steps**

**Author**

Chris Koelsch
Business Technology Administration – UMBC
Aspiring Data Scientist / Machine Learning Engineer
