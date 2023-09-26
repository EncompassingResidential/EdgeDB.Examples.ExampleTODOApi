CREATE MIGRATION m16evyqaxzkox6liqly3akkdmg5wwbkfpqph6par5hiz3n2kiedrva
    ONTO initial
{
  CREATE SCALAR TYPE default::State EXTENDING enum<NotStarted, InProgress, Complete>;
  CREATE TYPE default::TODO {
      CREATE REQUIRED PROPERTY date_created: std::datetime {
          SET default := (std::datetime_current());
      };
      CREATE REQUIRED PROPERTY description: std::str;
      CREATE REQUIRED PROPERTY state: default::State;
      CREATE REQUIRED PROPERTY title: std::str;
  };
};
