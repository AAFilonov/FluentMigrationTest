using System;
using System.Text.RegularExpressions;
using FluentMigrator;

namespace Migrations.@abstract
{
    public abstract class SQLMigration : Migration
    {
        protected void ExecuteScript(string pathToSqlFile)
        {

            var path = MigratorConfig.getCurrentPath();
            var sqlLocation = MigratorConfig.getSqlLocations();
            Execute.Script(path + sqlLocation + pathToSqlFile);
        }
    }
}