using System;
using System.IO;
using System.Reflection;
using Microsoft.Extensions.DependencyInjection;
using FluentMigrator.Runner;
using Microsoft.Extensions.Configuration;

namespace Migrations
{
    public static class MigratorConfig
    {
        public static string getCurrentPath()
        {
            var path = Directory.GetCurrentDirectory();
            var parent = Directory.GetParent(path);
            return parent + String.Format("\\{0}\\", Assembly.GetCallingAssembly().GetName().Name);
        }

        public static string getSqlLocations()
        {
            return "/migration";
        }
    }
}