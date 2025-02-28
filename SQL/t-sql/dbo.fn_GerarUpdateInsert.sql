--use DL_NECXT

ALTER FUNCTION dbo.GerarUpdateInsert
(
    @TabelaA NVARCHAR(128),					-- Nome da primeira tabela (destino)
    @TabelaB NVARCHAR(128),					-- Nome da segunda tabela (origem)
    @Chaves NVARCHAR(MAX),					-- Chave(s) de compara��o (separadas por v�rgula)
    @Tipo INT,								-- 1 para UPDATE, 2 para INSERT
    @IgnorarColunas NVARCHAR(MAX) = NULL	-- Colunas a serem ignoradas (separadas por v�rgula)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @SQL_UPDATE NVARCHAR(MAX), 
            @SQL_INSERT NVARCHAR(MAX), 
            @SQL_RESULT NVARCHAR(MAX),
            @SchemaA NVARCHAR(128);


    ;WITH Colunas AS (
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_NAME = @TabelaA
        AND TABLE_SCHEMA = @SchemaA
        AND (@IgnorarColunas IS NULL OR COLUMN_NAME NOT IN (
            SELECT TRIM(value) FROM STRING_SPLIT(@IgnorarColunas, ',')
        ))
    )
    SELECT 
        @SQL_UPDATE = (
            SELECT STRING_AGG(CAST(QUOTENAME(A.COLUMN_NAME) + ' = B.' + QUOTENAME(A.COLUMN_NAME) AS NVARCHAR(MAX)), ', ')
            FROM Colunas A
        ),
        @SQL_INSERT = (
            SELECT STRING_AGG(CAST(QUOTENAME(A.COLUMN_NAME) AS NVARCHAR(MAX)), ', ')
            FROM Colunas A
        );

    -- Monta a instru��o UPDATE
    SET @SQL_UPDATE = 
        'UPDATE A SET ' + @SQL_UPDATE + 
        ' FROM ' +  QUOTENAME(@TabelaA) + ' A' +
        ' JOIN ' +  QUOTENAME(@TabelaB) + ' B' +
        ' ON ' + (
            SELECT STRING_AGG(CAST('A.' + QUOTENAME(value) + ' = B.' + QUOTENAME(value) AS NVARCHAR(MAX)), ' AND ')
            FROM STRING_SPLIT(@Chaves, ',')
        );

    -- Monta a instru��o INSERT
    SET @SQL_INSERT = 
        'INSERT INTO ' +  QUOTENAME(@TabelaA) + ' (' + @SQL_INSERT + ')' +
        ' SELECT ' + @SQL_INSERT +
        ' FROM ' + QUOTENAME(@TabelaB) + ' B';

    -- Adiciona a cl�usula NOT EXISTS, se necess�rio
    IF @Chaves IS NOT NULL
    BEGIN
        SET @SQL_INSERT = @SQL_INSERT +
            ' WHERE NOT EXISTS (SELECT 1 FROM ' +  QUOTENAME(@TabelaA) + ' A WHERE ' + 
            (
                SELECT STRING_AGG(CAST('A.' + QUOTENAME(value) + ' = B.' + QUOTENAME(value) AS NVARCHAR(MAX)), ' AND ')
                FROM STRING_SPLIT(@Chaves, ',')
            ) + ')'
    END

    -- Retornar UPDATE ou INSERT conforme @Tipo
    IF @Tipo = 1
        SET @SQL_RESULT = @SQL_UPDATE;
    ELSE IF @Tipo = 2
        SET @SQL_RESULT = @SQL_INSERT;
    ELSE
        SET @SQL_RESULT = 'Par�metro @Tipo inv�lido. Use 1 para UPDATE ou 2 para INSERT.';

    RETURN @SQL_RESULT;
END
GO
