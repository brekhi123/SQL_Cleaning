-- 1. Remove duplicates if exists
-- 2. Standardize the data (spelling mistakes and more)
-- 3. Null or blank values
-- 4. Remove Any Rows or Columns (irrelevant columns)
-- Note: DO NOT WORK W/ RAW DATA AND CREATE A COPY


CREATE TABLE
    layoffs_staging
LIKE
    layoffs;

SELECT *
FROM layoffs_staging;

INSERT 
    layoffs_staging
SELECT *
FROM layoffs;



-- Anything with row_num > 1 is flagged as a duplicate based on the columns used in PARTITION BY but delete wont work here
WITH duplicate_cte AS
(
SELECT *,
    ROW_NUMBER() OVER (
    PARTITION BY company, `location`, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
FROM layoffs_staging
)
DELETE
FROM duplicate_cte
WHERE row_num > 1;


CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


SELECT *
FROM layoffs_staging2;

-- Inserted a column w/ row num from the cte made above so duplicates can be easily removed
INSERT INTO layoffs_staging2
    SELECT *,
        ROW_NUMBER() OVER (
        PARTITION BY company, `location`, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num
    FROM layoffs_staging

DELETE
FROM layoffs_staging2
WHERE row_num > 1;


-- 2. Standardize the data 
-- Space in the beginning of the company column
-- 

UPDATE
    layoffs_staging2
SET 
    company = TRIM(company);

SELECT DISTINCT industry
FROM layoffs_staging2;

-- Want to group HR and Support AS People Operations
-- Data, Security, Hardware AS Tech Infrastructure

UPDATE
    layoffs_staging2
SET 
    industry = 
        CASE
        WHEN industry = 'HR' OR industry = 'Support' THEN 'People Operations'
        WHEN industry = 'Data' OR  industry = 'Security' OR industry = 'Hardware' THEN 'Tech Infrastructure'
        ELSE industry
        END;

SELECT
    DISTINCT industry
FROM layoffs_staging2;

-- Fixes the trailing '.' from the values in the country column
SELECT 
    DISTINCT country, TRIM(TRAILING '.' FROM country)
FROM layoffs_staging2
ORDER BY 1;

UPDATE
    layoffs_staging2
SET
    country = TRIM(TRAILING '.' FROM country)
WHERE
    country LIKE 'United States%';
SELECT
    DISTINCT country
FROM
    layoffs_staging2;

-- Conversion to date from string and then to the date type
SELECT 
    `date`,
    STR_TO_DATE(`date`, '%m/%d/%Y')
FROM layoffs_staging2;

UPDATE
    layoffs_staging2
SET
    date = STR_TO_DATE(`date`, '%m/%d/%Y');

SELECT 
    `date`
FROM layoffs_staging2;

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;

-- 3. Null or Blank Values

SELECT *
FROM layoffs_staging2
WHERE company = 'Airbnb';


UPDATE layoffs_staging2
SET industry = NULL
WHERE industry = '';


SELECT t1.industry, t2.industry
FROM layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
    AND t1.location = t2.location
WHERE (t1.industry IS NULL)
AND t2.industry IS NOT NULL;


UPDATE layoffs_staging2 t1
JOIN layoffs_staging2 t2
    ON t1.company = t2.company
    AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- Could not populate Bally's Interactive because Industry was never labelled for any of these instances ie. cannot look at other instances of the company where the industry is not null but labelled Airbnb as travel manually
SELECT *
FROM layoffs_staging2
WHERE industry IS NULL OR industry = '';

UPDATE layoffs_staging2
SET industry = 'Travel'
WHERE company = 'Airbnb'


SELECT *
FROM layoffs_staging2
WHERE 
    total_laid_off IS NULL
    AND
    percentage_laid_off IS NULL;

-- Deleted the data where total laid off and percentage laid off are null (this will not help us if we dont have the main metrics)
DELETE
FROM layoffs_staging2
WHERE 
    total_laid_off IS NULL
    AND
    percentage_laid_off IS NULL;

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

SELECT *
FROM layoffs_staging2;
