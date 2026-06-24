def run_loader():
    import json
    import pandas as pd
    import datetime
    from sqlalchemy import create_engine, text
    from sqlalchemy import inspect
    from pandas.errors import ParserError
    from pandas.errors import EmptyDataError
    import os

    db_user = os.environ['DB_USER']
    db_password = os.environ['DB_PASSWORD']
    db_host = os.environ['DB_HOST']
    db_port = os.environ['DB_PORT']
    db_name = os.environ['DB_NAME']


    def validate_infile():
        """Loading the raw file"""
        try:
            dataframe = pd.read_csv("/opt/airflow/accounting_pipeline/data/raw_ledger_export_multimonth.csv",
                             delimiter=";",
                             usecols=range(17),
                             dtype=str,
                             keep_default_na=False)
        except FileNotFoundError:
            print("File does not exist")
        except PermissionError:
            print("No permission to read file")
        except ParserError as e:
            print(e)
        except EmptyDataError:
            print("File is empty")
        else:
            return dataframe

    df = validate_infile()

    if df.empty:
        file_loaded = False
    else:
        file_loaded = True

    df.columns = df.columns.str.strip()



    """Renaming columns"""
    column_map = {
        'Nr_dok':       'document_number',
        'Typ_dok':      'document_type',
        'Data_dok':     'document_date_raw',
        'Data_ks':      'posting_date_raw',
        'Konto_Wn':     'debit_account',
        'Konto_Ma':     'credit_account',
        'Kwota':        'amount_original_raw',
        'Waluta':       'currency',
        'Kwota_PLN':    'amount_pln_raw',
        'Kurs':         'exchange_rate_raw',
        'Opis':         'description',
        'Podmiot':      'counterparty_name',
        'NIP':          'counterparty_nip',
        'Nr_faktury':   'invoice_number',
        'Okres_ks':     'accounting_period',
        'Użytkownik':   'entered_by',
        'Data_wpisu':   'entered_at_raw',
    }

    df = df.rename(columns=column_map)



    """Stripping whitespace from column names"""
    df.columns = df.columns.str.strip()
    if file_loaded:
        columns_stripped = True
    else:
        columns_stripped = False


    """Converting dates to datetime"""
    cols1 = None
    dates_converted = False

    def convert_dates(columns):
        for column in columns:
            df[column] = pd.to_datetime(df[column], errors='coerce', format="mixed")

    try:
        cols1 = ["document_date_raw", "posting_date_raw", "entered_at_raw"]
        if len(cols1) == 3:
            convert_dates(cols1)
            if file_loaded:
                dates_converted = True
        else:
            raise KeyError
    except KeyError:
        print(f"Incorrect number of columns in {cols1}, should be {["document_date_raw", "posting_date_raw", "entered_at_raw"]}")



    """Removing useless punctuation from NIP numbers"""
    nip_validated = False
    def validate_nip(nip_col):
        df[nip_col] = df[nip_col].str.replace(r'[^\w\s]+', '', regex=True)

    validate_nip("counterparty_nip")
    if file_loaded:
        nip_validated = True



    """Changing the commas for dots in money amounts"""
    punctuation_fixed = False
    def fix_punctuation(series):
        return (series.str.replace(".", "", regex=False)
                .str.replace(",", ".", regex=False)
                .pipe(pd.to_numeric, errors='coerce'))

    try:
        for col in ["amount_original_raw", "amount_pln_raw", 'exchange_rate_raw']:
            df[col] = fix_punctuation(df[col])
        if file_loaded:
            punctuation_fixed = True
    except AttributeError as e:
        print(e)




    """Exporting table to sql"""
    engine = create_engine(
        f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
)

    inspector = inspect(engine)
    table_exists = inspector.has_table("raw_ledger", schema="raw")
    exported_file_to_sql = False

    if file_loaded:
        if table_exists:
            with engine.connect() as conn:
                conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))           #added this
                conn.execute(text("TRUNCATE TABLE raw.raw_ledger"))
                # conn.commit()     #caused errors: commented it out
            df.to_sql(name="raw_ledger",
                  con=engine,
                  schema="raw",
                  if_exists="append",
                  index=False,
                  method="multi",
        )
        else:
            with engine.connect() as conn:           #added this
                conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))           #added this
            df.to_sql(name="raw_ledger",
              con=engine,
              schema="raw",
              if_exists="replace",
              index=False,
              method="multi",
        )


        print(f"\nLoaded {len(df)} rows into raw.raw_ledger")
        exported_file_to_sql = True



    """Create a JSON summary"""
    def get_summary(infile_check, col_strip_check, dates_check, nip_check, sql_check):
        return (
            {"Time": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
             "File loaded": infile_check,
             "Columns stripped": col_strip_check,
             "Dates converted": dates_check,
             "NIP number cleaned": nip_check,
             "Numbers refactored from Polish to Universal format": punctuation_fixed,
             "Loaded into SQL": sql_check,
             "Numeric errors found": int(df["amount_pln_raw"].isnull().sum()),
             "Amount of date errors found": df[["document_date_raw", "posting_date_raw", 'entered_at_raw']].isnull().sum().to_dict(),
             "Document types found": df["document_type"].value_counts().to_dict()}


        )

    path = "/opt/airflow/accounting_pipeline/data/loader_report.json"

    def export_to_json(filepath, data):
        with open(filepath, "a") as f:
            json.dump(data, f, indent=2)

    export_to_json(path, get_summary(file_loaded, columns_stripped, dates_converted, nip_validated, exported_file_to_sql))

