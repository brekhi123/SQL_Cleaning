# Layoffs Data Cleaning Project

## Overview

This project focuses on **cleaning and preparing a dataset of company layoffs** to ensure it is suitable for downstream analysis. The dataset includes company information, layoff counts, funding, and other relevant metrics. This pipeline ensures that data is **de‑duplicated, standardized, and cleaned for nulls or inconsistencies**, following best practices in data handling.

---

## Objectives

1. **Remove Duplicates**  
   Eliminate exact or near‑duplicate entries based on core columns such as company, location, industry, and date.

2. **Standardize the Data**  
   Fix formatting inconsistencies, spelling variations, trailing spaces, and categorical groupings.

3. **Handle Null or Blank Values**  
   Fill missing values where possible using reliable lookup logic; remove rows that lack key metrics.

4. **Drop Irrelevant Columns**  
   Remove temporary or helper columns (e.g., `row_num`) after usage.

> ⚠️ **Note:** All cleaning was performed on a **copy** of the original raw data (`layoffs_staging`), following data engineering best practices. The original table remains unchanged.

---

## Steps Performed

### 1. Table Initialization

```sql
CREATE TABLE layoffs_staging LIKE layoffs;
INSERT INTO layoffs_staging SELECT * FROM layoffs;
```

A staging copy was created to avoid modifying the raw dataset.

---

### 2. Duplicate Removal

Used `ROW_NUMBER()` with a CTE to identify duplicate rows based on:  
`company`, `location`, `industry`, `total_laid_off`, `percentage_laid_off`, `date`, `stage`, `country`, `funds_raised_millions`.

```sql
-- Added row numbers
INSERT INTO layoffs_staging2
SELECT *,
  ROW_NUMBER() OVER (
    PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, date, stage, country, funds_raised_millions
  ) AS row_num
FROM layoffs_staging;

-- Removed duplicates
DELETE FROM layoffs_staging2 WHERE row_num > 1;
```

---

### 3. Standardization

- Trimmed whitespace from `company` values.  
- Merged related `industry` categories:  
  - `HR`, `Support` → **People Operations**  
  - `Data`, `Security`, `Hardware` → **Tech Infrastructure**  
- Removed trailing periods from `country` entries.  
- Converted `date` from `TEXT` to `DATE` format using `STR_TO_DATE`.

```sql
UPDATE layoffs_staging2
SET company = TRIM(company);

UPDATE layoffs_staging2
SET industry = CASE
  WHEN industry IN ('HR', 'Support') THEN 'People Operations'
  WHEN industry IN ('Data', 'Security', 'Hardware') THEN 'Tech Infrastructure'
  ELSE industry
END;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)
WHERE country LIKE 'United States%';

UPDATE layoffs_staging2
SET date = STR_TO_DATE(date, '%m/%d/%Y');

ALTER TABLE layoffs_staging2 MODIFY COLUMN date DATE;
```

---

### 4. Null or Missing Value Handling

- Replaced blank strings in `industry` with `NULL`.  
- Imputed missing `industry` values using matching `company` + `location` pairs where possible.  
- Manually fixed known company (`Airbnb` → **Travel**).  
- Removed rows where **both** `total_laid_off` and `percentage_laid_off` were null (incomplete data).

```sql
UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';

-- Impute industry using self‑join logic
UPDATE t1
SET t1.industry = t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
  ON t1.company = t2.company
  AND t1.location = t2.location
WHERE t1.industry IS NULL
  AND t2.industry IS NOT NULL;

UPDATE layoffs_staging2
SET industry = 'Travel'
WHERE company = 'Airbnb';

DELETE FROM layoffs_staging2
WHERE total_laid_off IS NULL
  AND percentage_laid_off IS NULL;
```

---

### 5. Cleanup

Dropped helper column `row_num` used in de‑duplication.

```sql
ALTER TABLE layoffs_staging2 DROP COLUMN row_num;
```

---

## Final Output

The cleaned dataset in **`layoffs_staging2`** is now:

- Free of duplicates  
- Standardized across all key text and categorical fields  
- Purged of unusable rows with critical nulls  
- Safe for further analysis or visualization  

---

## 💡 Notes

- Data integrity and original structure were preserved throughout.  
- Changes were executed in controlled stages using SQL best practices (CTEs, window functions, normalization).  
- Manual inspection complemented automated cleaning to ensure completeness.  

---

## Files

| File | Description |
|------|-------------|
| `layoffs.sql` | Raw data structure (not modified) |
| `layoffs_staging` | Copy for intermediate operations |
| `layoffs_staging2` | Final cleaned table |

---

## 📊 Potential Next Steps

- Visualize layoff trends over time or by industry.  
- Perform country‑level comparisons and insights.  
- Load the cleaned data into a BI tool or dashboard for interactive exploration.  
