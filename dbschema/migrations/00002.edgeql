CREATE MIGRATION m1yem2i2f6e2v6occd5x5dhmcyxhayokdbsvtk64rmceypp2okpvvq
    ONTO m16evyqaxzkox6liqly3akkdmg5wwbkfpqph6par5hiz3n2kiedrva
{
  ALTER TYPE default::TODO {
      ALTER PROPERTY title {
          CREATE CONSTRAINT std::exclusive;
          CREATE CONSTRAINT std::min_len_value(8);
      };
  };
};
