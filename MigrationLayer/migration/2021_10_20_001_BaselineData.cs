using System;
using FluentMigrator;
using Migrations.@abstract;

namespace Migrations
{
  [Migration(2021_10_20_002,"Baseline data")]
    public class BaselineData : SQLMigration
    {
        public override void Up()
        {
            ExecuteScript("/scripts/01-baseline_data.sql");
        }

        public override void Down()
        {
          
        }
    }
}