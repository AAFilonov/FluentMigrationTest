GO
USE [MigrationTest]
GO
/****** Object:  User [WebAppDiplomaMatching]    Script Date: 31.10.2021 15:09:48 ******/
CREATE USER [WebAppDiplomaMatching] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  User [diplomamatchinguser]    Script Date: 31.10.2021 15:09:48 ******/
CREATE USER [diplomamatchinguser] WITHOUT LOGIN WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [WebAppDiplomaMatching]
GO
ALTER ROLE [db_datareader] ADD MEMBER [WebAppDiplomaMatching]
GO
ALTER ROLE [db_datawriter] ADD MEMBER [WebAppDiplomaMatching]
GO
ALTER ROLE [db_owner] ADD MEMBER [diplomamatchinguser]
GO
/****** Object:  Schema [dbo_v]    Script Date: 31.10.2021 15:09:48 ******/
CREATE SCHEMA [dbo_v]
GO
/****** Object:  Schema [glob]    Script Date: 31.10.2021 15:09:48 ******/
CREATE SCHEMA [glob]
GO
/****** Object:  Schema [napp]    Script Date: 31.10.2021 15:09:48 ******/
CREATE SCHEMA [napp]
GO
/****** Object:  Schema [napp_in]    Script Date: 31.10.2021 15:09:48 ******/
CREATE SCHEMA [napp_in]
GO
/****** Object:  Schema [stg]    Script Date: 31.10.2021 15:09:48 ******/
CREATE SCHEMA [stg]
GO
/****** Object:  Schema [tmp]    Script Date: 31.10.2021 15:09:48 ******/
CREATE SCHEMA [tmp]
GO
/****** Object:  UserDefinedTableType [dbo].[ProjectQuota]    Script Date: 31.10.2021 15:09:48 ******/
CREATE TYPE [dbo].[ProjectQuota] AS TABLE(
                                             [ProjectID] [int] NOT NULL,
                                             [Quota] [smallint] NULL
                                         )
GO
/****** Object:  UserDefinedTableType [dbo].[StrList]    Script Date: 31.10.2021 15:09:48 ******/
CREATE TYPE [dbo].[StrList] AS TABLE(
                                        [value] [nvarchar](max) NULL,
                                        [id] [int] IDENTITY(1,1) NOT NULL
                                    )
GO
/****** Object:  UserDefinedTableType [dbo].[TutorsChoice_1]    Script Date: 31.10.2021 15:09:48 ******/
CREATE TYPE [dbo].[TutorsChoice_1] AS TABLE(
                                               [ChoiseID] [int] NULL,
                                               [SortOrderNumber] [smallint] NULL,
                                               [IsInQuota] [bit] NULL
                                           )
GO
/****** Object:  UserDefinedFunction [dbo].[agg_StrList]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 19.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [dbo].[agg_StrList]
(
    @StrList dbo.StrList readonly
,@Separator nvarchar(100)
)
    RETURNS nvarchar(max)
AS
BEGIN

    declare
        @MaxID int = (select max(id) from @StrList)
        ,@CurID int = 1
        ,@AggStr nvarchar(max) = '';

    while (@CurID < @MaxID)
        begin
            set @AggStr = @AggStr
                + (select value from @StrList where id = @CurID)
                + @Separator
            ;
            set @CurID = @CurID + 1 ;

        end

    set @AggStr = @AggStr
        + (select value from @StrList where id = @MaxID)

    return @AggStr;

END



GO
/****** Object:  UserDefinedFunction [napp].[get_CommonQuota_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 19.02.2020
-- Update date: 13.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_CommonQuota_ByTutor]
(
    @TutorID int
)
    RETURNS int
AS
BEGIN
    declare
        @CommonQuotaQty int
    ;

    set @CommonQuotaQty =
            (
                select top 1
                    q.Qty
                from
                    dbo_v.ActiveCommonQuotas q with (nolock)
                where
                        q.TutorID = @TutorID
            )
    ;


    return coalesce( @CommonQuotaQty, -1);


END




GO
/****** Object:  UserDefinedFunction [napp].[get_CommonQuota_Requests_NotificationCount_ByExecutive]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 24.02.2020
-- Update date: 10.04.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_CommonQuota_Requests_NotificationCount_ByExecutive]
(
    @UserID int
,@MatchingID int
)
    RETURNS int
AS
BEGIN
    declare @NotificationCount int;

    if not exists (	select 1
                       from
                           dbo.Users_Roles ExecutiveUser with (nolock)

                               join  dbo.Roles ExecutiveRole with (nolock) on
                                       ExecutiveRole.RoleCode = 3 --executive
                                   and
                                       ExecutiveRole.RoleID = ExecutiveUser.RoleID
                       where
                               ExecutiveUser.UserID = @UserID
                         and
                               ExecutiveUser.MatchingID = @MatchingID
        )
        return -1;


    set @NotificationCount = (	select count(*)
                                  from
                                      dbo.Tutors t with(nolock)

                                          join dbo.CommonQuotas q with(nolock)  on
                                              q.TutorID = t.TutorID

                                          join dbo.QuotasStates qs with (nolock) on
                                              qs.QuotaStateID = q.QuotaStateID
                                  where
                                          t.MatchingID = @MatchingID
                                    and
                                          qs.QuotaStateName = 'requested'
                                    -------------------------------
                                    and
                                          q.IsNotification = 1
        ------------------------------				
    )

    return coalesce(@NotificationCount, 0);


END



GO
/****** Object:  UserDefinedFunction [napp].[get_IsCommonQuotaNotification_ByExecutive]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 12.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_IsCommonQuotaNotification_ByExecutive]
(
    @UserID int
,@MatchingID int
)
    RETURNS bit
AS
BEGIN

    if not exists (	select 1
                       from
                           dbo.Users_Roles ExecutiveUser with (nolock)

                               join  dbo.Roles ExecutiveRole with (nolock) on
                                       ExecutiveRole.RoleCode = 3 --executive
                                   and
                                       ExecutiveRole.RoleID = ExecutiveUser.RoleID
                       where
                               ExecutiveUser.UserID = @UserID
                         and
                               ExecutiveUser.MatchingID = @MatchingID
        )
        return 0;

    if exists (		select
                           1
                       from
                           dbo.Tutors t with(nolock)

                               join dbo.CommonQuotas q with(nolock)  on
                                   q.TutorID = t.TutorID

                               join dbo.QuotasStates qs with (nolock) on
                                   qs.QuotaStateID = q.QuotaStateID
                       where
                               t.MatchingID = @MatchingID
                         and
                               qs.QuotaStateName = 'requested'
                         and
                               q.IsNotification = 1
        )
        return 1;

    return 0;




END




GO
/****** Object:  UserDefinedFunction [napp].[get_IsCommonQuotaNotification_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 12.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_IsCommonQuotaNotification_ByTutor]
(
    @TutorID int
)
    RETURNS bit
AS
BEGIN

    if exists (		select
                           1
                       from dbo.CommonQuotas q with(nolock)

                                join dbo.QuotasStates qs with (nolock) on
                               qs.QuotaStateID = q.QuotaStateID
                       where
                               q.TutorID = @TutorID
                         and
                               qs.QuotaStateName != 'requested'
                         and
                               q.IsNotification = 1
        )
        return 1;

    return 0;




END




GO
/****** Object:  UserDefinedFunction [napp].[get_IsReadyToStart_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 24.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_IsReadyToStart_ByTutor]
(
    @TutorID int
)
    RETURNS int
AS
BEGIN
    declare
        @IsReady bit
    ;

    set @IsReady =
            (
                select top 1
                    Tutor.IsReadyToStart
                from
                    dbo.Tutors Tutor with (nolock)
                where
                        Tutor.TutorID = @TutorID
            )
    ;

    return @IsReady;


END



GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage2_Main]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 29.02.2020
-- Update date: 06.05.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StatisticStage2_Main]
(
    @MatchingID int
)

    RETURNS @Statistic TABLE
                       (
                           StatName			nvarchar(300)
                           ,StatValue			int
                           ,StatValueFrom		int
                           ,StatValue_Str		nvarchar(20)
                           ,StatPercentage		numeric(6, 2)

                       )
AS
begin
    if (@MatchingID is null)
        return;

    declare
        @TutorsAll int
        ,@TutorsVisitedOnCurStage int
        ,@TutorsReadyToStart int
        ,@CommonQuotaSum int
        ,@CommonQuotaAvg int
        ,@StudentsAll int
        ,@StudentsVisitedOnCurStage int
        ,@ProjectsAll int
        ,@ProjectsAvg int
    ;

    select
            @TutorsAll = count (*)
         ,@TutorsVisitedOnCurStage = count(	case
                                                   when Tutor.LastVisitDate >= CurrentStage.StartDate  then
                                                       1
                                                   else
                                                       null
        end)
         ,@TutorsReadyToStart = count(	case
                                              when Tutor.IsReadyToStart = 1 then
                                                  1
                                              else
                                                  null
        end)
         ,@CommonQuotaSum = sum(Quota.Qty)
         ,@CommonQuotaAvg = avg(Quota.Qty)
    from dbo_v.Tutors Tutor

             cross apply
         (
             select *
             from
                 napp.get_CurrentStage_ByMatching(@MatchingID)
         ) CurrentStage

             --join dbo.Projects DefaultProject with (nolock) on 
             --	DefaultProject.TutorID = Tutor.TutorID
             --	and 
             --	DefaultProject.IsDefault = 1

             join dbo_v.ActiveCommonQuotas Quota on
            Quota.TutorID = Tutor.TutorID
         --and 
         --Quota.IsCommon = 1
    where
            Tutor.MatchingID = @MatchingID
    ;


    select
            @StudentsAll = count(*)
         ,@StudentsVisitedOnCurStage = count(case
                                                 when Student.LastVisitDate >= CurrentStage.StartDate  then
                                                     1
                                                 else
                                                     null
        end)
    from
        dbo_v.Students Student

            cross apply
        (
            select *
            from
                napp.get_CurrentStage_ByMatching(@MatchingID)
        ) CurrentStage
    where
            Student.MatchingID = @MatchingID
    ;

    select
            @ProjectsAll = count (ProjectID)
         ,@ProjectsAvg = count (ProjectID) / count (distinct TutorID)
    from
        dbo.Projects with (nolock)
    where
            MatchingID = @MatchingID
    ;


    insert into @Statistic
    (
        StatName
    ,StatValue
    ,StatValueFrom
    ,StatValue_Str
    ,StatPercentage
    )
    select
        'Участвуют в распределении: преподавателей' as StatName
         ,@TutorsAll	as StatValue
         ,null		as StatValueFrom
         ,cast (@TutorsAll as nvarchar (20) ) 	 as StatValue_Str
         ,null		as StatPercentage

    union all

    select
        'Участвуют в распределении: студентов'
         ,@StudentsAll
         ,null
         ,cast (@StudentsAll as nvarchar (20) )
         ,null

    union all

    select
        'Посетили систему на текущем этапе: Преподавателей'
         ,@TutorsVisitedOnCurStage
         ,@TutorsAll
         ,cast (@TutorsVisitedOnCurStage as nvarchar (10) )
        + ' / '
        + cast (@TutorsAll as nvarchar (10) )

         ,round (cast(@TutorsVisitedOnCurStage as numeric(5, 1))
                     /
                 cast(@TutorsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Посетили систему на текущем этапе: Студентов'
         ,@StudentsVisitedOnCurStage
         ,@StudentsAll
         ,cast (@StudentsVisitedOnCurStage as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsVisitedOnCurStage as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Готово к распределению: Преподавателей'
         ,@TutorsReadyToStart
         ,@TutorsAll
         ,cast (@TutorsReadyToStart  as nvarchar (10) )
        + ' / '
        + cast (@TutorsAll as nvarchar (10) )
         ,round (
                cast(@TutorsReadyToStart  as numeric(5, 1))
                /
                cast(@TutorsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Квота: сумма'
         ,@CommonQuotaSum
         ,null
         ,cast (@CommonQuotaSum  as nvarchar (20))
         ,null

    union all

    select
        'Квота: средняя'
         ,@CommonQuotaAvg
         ,null
         ,cast (@CommonQuotaAvg  as nvarchar (20))
         ,null

    union all

    select
        'Проектов: всего'
         ,@ProjectsAll
         ,null
         ,cast (@ProjectsAll as nvarchar (20) )
         ,null

    union all

    select
        'Проектов: в среднем на преподавателя'
         ,@ProjectsAvg
         ,null
         ,cast (@ProjectsAvg as nvarchar (20) )
         ,null

    ;

    return;

end

GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage3_Main]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 07.03.2020
-- Update date: 11.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StatisticStage3_Main]
(
    @MatchingID int
)

    RETURNS @Statistic TABLE
                       (
                           StatName			nvarchar(300)
                           ,StatValue			int
                           ,StatValueFrom		int
                           ,StatValue_Str		nvarchar(max)
                           ,StatPercentage		numeric(6, 2)

                       )
AS
begin
    if (@MatchingID is null)
        return;

    declare
        @TutorsAll int
        ,@TutorsVisitedOnCurStage int
        ,@StudentsAll int
        ,@StudentsVisitedOnCurStage int
        ,@StudentsWithPreferences int
        ,@ProjectsPreferencesAvg int


    ;

    --=========== Tutors ===========-
    select
            @TutorsAll = count (*)
         ,@TutorsVisitedOnCurStage = count(	case
                                                   when Tutor.LastVisitDate >= CurrentStage.StartDate  then
                                                       1
                                                   else
                                                       null
        end)
    from dbo_v.Tutors Tutor

             cross apply
         (
             select *
             from
                 napp.get_CurrentStage_ByMatching(@MatchingID)
         ) CurrentStage

    where
            Tutor.MatchingID = @MatchingID
    ;

--=========== Students ===========-
    select
            @StudentsAll = count(Student.StudentID)
         ,@StudentsVisitedOnCurStage = count(case
                                                 when Student.LastVisitDate >= CurrentStage.StartDate  then
                                                     1
                                                 else
                                                     null
        end)
         ,@StudentsWithPreferences = count (Preference.StudentID)
         ,@ProjectsPreferencesAvg = avg (Preference.CountProjects)


    from
        dbo_v.Students Student

            cross apply
        (
            select *
            from
                napp.get_CurrentStage_ByMatching(@MatchingID)
        ) CurrentStage

            left join
        (
            select
                StudentID
                 , count(PreferenceID) as CountProjects
            from
                dbo.StudentsPreferences  with (nolock)
            group by
                StudentID
        ) as Preference
        on Preference.StudentID = Student.StudentID

    where
            Student.MatchingID = @MatchingID
    ;

--=========== Top 3 ===========-
    declare
        @TopProjects dbo.StrList
        ,@TopTutors  dbo.StrList;

    insert into @TopProjects (value)
    select top 3
            coalesce (Project.ProjectName, 'Записаться к преподавателю')
            + ' : ' + Tutor.NameAbbreviation + ' ('
            + cast (count(Preference.PreferenceID) as nvarchar (10)) + ')'

    from
        dbo.Projects Project with (nolock)

            join dbo_v.Tutors Tutor with (nolock) on
                Tutor.TutorID = Project.TutorID

            join dbo.StudentsPreferences Preference with (nolock) on
                Preference.ProjectID = Project.ProjectID
    where
            Project.MatchingID = @MatchingID
    group by
        Project.ProjectName
           ,Tutor.NameAbbreviation

    order by
        count(Preference.PreferenceID) desc;

    insert into @TopTutors (value)
    select top 3
            Tutor.NameAbbreviation
            + ' (' + cast (count(Preference.PreferenceID) as nvarchar (10)) + ')'

    from  dbo_v.Tutors Tutor with (nolock)

              join dbo.Projects Project with (nolock) on
            Project.TutorID = Tutor.TutorID

              join dbo.StudentsPreferences Preference with (nolock) on
            Preference.ProjectID = Project.ProjectID


    where
            Tutor.MatchingID = @MatchingID
    group by
        Tutor.NameAbbreviation

    order by
        count(Preference.PreferenceID) desc
    ;


--========== Заполнение статистики ==========--
    insert into @Statistic
    (
        StatName
    ,StatValue
    ,StatValueFrom
    ,StatValue_Str
    ,StatPercentage
    )
    select
        'Участвуют в распределении: преподавателей' as StatName
         ,@TutorsAll	as StatValue
         ,null		as StatValueFrom
         ,cast (@TutorsAll as nvarchar (20) ) 	 as StatValue_Str
         ,null		as StatPercentage

    union all

    select
        'Участвуют в распределении: студентов'
         ,@StudentsAll
         ,null
         ,cast (@StudentsAll as nvarchar (20) )
         ,null

    union all

    select
        'Посетили систему на текущем этапе: Преподавателей'
         ,@TutorsVisitedOnCurStage
         ,@TutorsAll
         ,cast (@TutorsVisitedOnCurStage as nvarchar (10) )
        + ' / '
        + cast (@TutorsAll as nvarchar (10) )

         ,round (cast(@TutorsVisitedOnCurStage as numeric(5, 1))
                     /
                 cast(@TutorsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Посетили систему на текущем этапе: Студентов'
         ,@StudentsVisitedOnCurStage
         ,@StudentsAll
         ,cast (@StudentsVisitedOnCurStage as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsVisitedOnCurStage as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Сделали выбор: Студентов'
         ,@StudentsWithPreferences
         ,@StudentsAll
         ,cast (@StudentsWithPreferences  as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsWithPreferences  as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Среднее количество выбранных проектов'
         ,@ProjectsPreferencesAvg
         ,null
         ,cast (@ProjectsPreferencesAvg  as nvarchar (20))
         ,null

    union all

    select
        'Топ 3: Проекты'
         ,null
         ,null
         ,dbo.agg_StrList(@TopProjects, ', ')
         ,null

    union all

    select
        'Топ 3: Преподаватели'
         ,null
         ,null
         ,dbo.agg_StrList(@TopTutors, ', ')
         ,null
    ;

    return;

end


GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage3_Main_ProgressBars]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 07.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StatisticStage3_Main_ProgressBars]
(
    @MatchingID int
)

    RETURNS @Statistic TABLE
                       (
                           StatName			nvarchar(300)
                           ,StatValue			int
                           ,StatValueFrom		int
                           ,StatValue_Str		nvarchar(20)
                           ,StatPercentage		numeric(6, 2)

                       )
AS
begin
    if (@MatchingID is null)
        return;

    with StatGroup
             as
             (
                 select
                     [Group].GroupID
                      ,[Group].GroupName
                      ,count(Student.StudentID) as StudentAll
                      ,count(Preference.StudentID) as StudentWithPreferences
                 from
                     dbo.Groups [Group] with (nolock)

                         join dbo.Students Student with (nolock) on
                             Student.GroupID = [Group].GroupID

                         left join
                     (
                         select distinct
                             StudentID
                         from
                             dbo.StudentsPreferences  with (nolock)
                     ) as Preference
                     on Preference.StudentID = Student.StudentID


                 where
                         [Group].MatchingID = 1
                 group by
                     [Group].GroupID
                        ,[Group].GroupName
             )

    insert into @Statistic
    (
        StatName
    ,StatValue
    ,StatValueFrom
    ,StatValue_Str
    ,StatPercentage
    )

    select
        GroupName
         ,StudentWithPreferences
         ,StudentAll
         ,cast (StudentWithPreferences as nvarchar (10) )
        + ' / '
        + cast (StudentAll as nvarchar (10) )

         ,round (cast(StudentWithPreferences as numeric(5, 1))
                     /
                 cast(StudentAll as numeric(5, 1))
        ,2)
    from StatGroup

    return;

end


GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage4_Main]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.05.2020
-- Update date: 11.05.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StatisticStage4_Main]
(
    @MatchingID int
)

    RETURNS @Statistic TABLE
                       (
                           StatName			nvarchar(300)
                           ,StatValue			int
                           ,StatValueFrom		int
                           ,StatValue_Str		nvarchar(max)
                           ,StatPercentage		numeric(6, 2)

                       )
AS
begin
    if (@MatchingID is null)
        return;

    declare
        @TutorsAll int
        ,@TutorsVisitedOnCurStage int
        ,@TutorsWithAvailableChoice int
        ,@TutorsWithSelfChoice int

        ,@StudentsAll int
        ,@StudentsVisitedOnCurStage int
        ,@StudentsAllocated int
        ,@StudentsCantAllocated int
        ,@StudentsInQuota int

        ,@ProjectsAll int
        ,@ProjectClosed int


    ;

    --=========== Tutors ===========-
    select
            @TutorsAll = count (*)
         ,@TutorsVisitedOnCurStage = count(	case
                                                   when Tutor.LastVisitDate >= CurrentStage.StartDate  then
                                                       1
                                                   else
                                                       null
        end)

         ,@TutorsWithAvailableChoice = count (case when (coalesce(Choice.NotInQuotaCount, 0)!=0) then 1 end)
         ,@TutorsWithSelfChoice = count (case when (coalesce(Choice.SelfChoiceCount, 0)!=0) then 1 end)

    from dbo_v.Tutors Tutor

             cross apply
         (
             select *
             from
                 napp.get_CurrentStage_ByMatching(@MatchingID)
         ) CurrentStage

             left join	(
        select
            Project.TutorID as TutorID
             , count (case when TutorChoice.IsInQuota = 0 then 1 end) as NotInQuotaCount
             , count (case when CType.TypeName = 'Self' then 1 end) as SelfChoiceCount

        from
            dbo.TutorsChoice TutorChoice with (nolock)

                join dbo.Projects Project with (nolock) on
                    Project.ProjectID = TutorChoice.ProjectID

                join dbo.ChoosingTypes CType with (nolock) on
                    CType.TypeID = TutorChoice.TypeID

        where
                Project.MatchingID = @MatchingID
          and
                TutorChoice.StageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID)
        group by
            Project.TutorID
    ) as Choice on
            Choice.TutorID = Tutor.TutorID

    where
            Tutor.MatchingID = @MatchingID
    ;

--=========== Students ===========-
    select
            @StudentsAll = count(Student.StudentID)
         ,@StudentsVisitedOnCurStage = count(case
                                                 when Student.LastVisitDate >= CurrentStage.StartDate  then
                                                     1
                                                 else
                                                     null
        end)
         ,@StudentsInQuota = count (case when TutorChoice.IsInQuota = 1 then TutorChoice.ChoiceID end)
         ,@StudentsAllocated = count (AllocatedProject.ProjectID)
         ,@StudentsCantAllocated = count (case when TutorChoice.ChoiceID is null then 1 end)


    from
        dbo_v.Students Student

            cross apply
        (
            select *
            from
                napp.get_CurrentStage_ByMatching(@MatchingID)
        ) CurrentStage

            left join dbo.TutorsChoice TutorChoice with (nolock) on
                    TutorChoice.StudentID = Student.StudentID
                and
                    TutorChoice.StageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID)
            --and 
            --TutorChoice.IsInQuota = 1

            left join dbo.Projects AllocatedProject with (nolock) on
                    AllocatedProject.ProjectID = TutorChoice.ProjectID
                and
                    AllocatedProject.IsClosed = 1
                and
                    TutorChoice.IsInQuota = 1

    where
            Student.MatchingID = @MatchingID
    ;

--=========== Проекты ===========-
    select
            @ProjectsAll = count(*)
         ,@ProjectClosed = count( case when Project.IsClosed = 1 then 1 end)
    from
        dbo.Projects Project with (nolock)
    where
            Project.MatchingID = @MatchingID
    ;

--========== Заполнение статистики ==========--
    insert into @Statistic
    (
        StatName
    ,StatValue
    ,StatValueFrom
    ,StatValue_Str
    ,StatPercentage
    )
    select
        'Участвуют в распределении: преподавателей' as StatName
         ,@TutorsAll	as StatValue
         ,null		as StatValueFrom
         ,cast (@TutorsAll as nvarchar (20) ) 	 as StatValue_Str
         ,null		as StatPercentage

    union all

    select
        'Участвуют в распределении: студентов'
         ,@StudentsAll
         ,null
         ,cast (@StudentsAll as nvarchar (20) )
         ,null

    union all

    select
        'Посетили систему на текущем этапе: Преподавателей'
         ,@TutorsVisitedOnCurStage
         ,@TutorsAll
         ,cast (@TutorsVisitedOnCurStage as nvarchar (10) )
        + ' / '
        + cast (@TutorsAll as nvarchar (10) )

         ,round (cast(@TutorsVisitedOnCurStage as numeric(5, 1))
                     /
                 cast(@TutorsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Посетили систему на текущем этапе: Студентов'
         ,@StudentsVisitedOnCurStage
         ,@StudentsAll
         ,cast (@StudentsVisitedOnCurStage as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsVisitedOnCurStage as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Студентов распределено'
         ,@StudentsAllocated
         ,@StudentsAll
         ,cast (@StudentsAllocated  as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsAllocated  as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Студентов потенциально распределено'
         ,@StudentsInQuota  - @StudentsAllocated
         ,@StudentsAll
         ,cast (@StudentsInQuota - @StudentsAllocated  as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsInQuota - @StudentsAllocated  as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Студентов не может быть распределено'
         ,@StudentsCantAllocated
         ,@StudentsAll
         ,cast (@StudentsCantAllocated  as nvarchar (10) )
        + ' / '
        + cast (@StudentsAll as nvarchar (10) )
         ,round (
                cast(@StudentsCantAllocated  as numeric(5, 1))
                /
                cast(@StudentsAll as numeric(5, 1))
        ,2)

    union all

    select
        'Проектов закрыто'
         ,@ProjectClosed
         ,@ProjectsAll
         ,cast (@ProjectClosed  as nvarchar (10) )
        + ' / '
        + cast (@ProjectsAll as nvarchar (10) )
         ,round (
                cast(@ProjectClosed  as numeric(5, 1))
                /
                cast(@ProjectsAll as numeric(5, 1))
        ,2)
    ;

    return;

end




GO
/****** Object:  UserDefinedFunction [napp].[get_StudentID]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 04.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StudentID]
(
    @UserID int
,@ManchingID int
)
    RETURNS int
AS
BEGIN
    declare
        @StudentID int
    ;

    set @StudentID =
            (
                select top 1 UserRole.StudentID

                from
                    dbo.Users_Roles UserRole with (nolock)

                        join dbo.Roles [Role] with (nolock) on
                            [Role].RoleID = UserRole.RoleID

                where
                        UserRole.UserID = @UserID
                  and
                        UserRole.MatchingID = @ManchingID
                  and
                        [Role].RoleCode = 2 -- Student

            )
    ;

    return coalesce(@StudentID, -1);


END




GO
/****** Object:  UserDefinedFunction [napp].[get_TutorID]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 04.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_TutorID]
(
    @UserID int
,@ManchingID int
)
    RETURNS int
AS
BEGIN
    declare
        @TutorID int
    ;

    set @TutorID =
            (
                select top 1 UserRole.TutorID

                from
                    dbo.Users_Roles UserRole with (nolock)

                        join dbo.Roles [Role] with (nolock) on
                            [Role].RoleID = UserRole.RoleID

                where
                        UserRole.UserID = @UserID
                  and
                        UserRole.MatchingID = @ManchingID
                  and
                        [Role].RoleCode = 1 -- Tutor

            )
    ;

    return coalesce(@TutorID, -1);


END




GO
/****** Object:  UserDefinedFunction [napp].[get_User]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 31.01.2020
-- Update date: 11.02.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_User]
(
    @UserID int = null
,@Login nvarchar(50) = null
)
    RETURNS @User TABLE
                  (
                      UserID int
                      ,[Login] nvarchar(50)
                      ,LastVisitDate datetime
                      ,Email nvarchar(50)
                      ,[Name] nvarchar(100)
                      ,[Surname] nvarchar(100)
                      ,[Patronimic] nvarchar(100)
                      ,NameAbbreviation nvarchar(106)
                  )
AS
begin
    if ((@UserID is null) and (@Login is null))
        return;

    insert into @User
    (
        UserID
    ,[Login]
    ,LastVisitDate
    ,Email
    ,[Name]
    ,[Surname]
    ,[Patronimic]
    ,NameAbbreviation
    )
    select top 1
        [User].UserID
               ,[User].Login
               ,[User].LastVisitDate
               ,[User].Email
               ,[User].Name
               ,[User].Surname
               ,[User].Patronimic
               ,[User].Surname
        + ' ' + iif ([User].Name is not null, substring([User].Name,1, 1) , '' ) + '.'
        + ' ' + iif ([User].Patronimic is not null, substring([User].Patronimic,1, 1) , '' ) + '.'
        as NameAbbreviation

    from
        dbo.Users [User] with (nolock)

    where
            [User].UserID = coalesce(@UserID, [User].UserID)
      and
            [User].[Login] = coalesce(@Login, [User].[Login])
    ;

    return;

end
GO
/****** Object:  UserDefinedFunction [napp].[get_UserID]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 31.01.2020
-- Update date: 11.02.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_UserID]
(
    @Login nvarchar (50)
)
    RETURNS int
AS
BEGIN
    declare
        @UserID int
    ;

    set @UserID =
            (
                select top 1
                    u.UserID
                from
                    dbo.Users u
                where
                        u.[Login] = @Login
            )
    ;

    if (@UserID is not null)
        return @UserID;

    return -1;


END
GO
/****** Object:  UserDefinedFunction [napp].[get_UserMatchings]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 31.01.2020
-- Update date: 13.02.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_UserMatchings]
(
    @UserID int = null
,@Login nvarchar(50) = null
)
    RETURNS @UserMatchings TABLE
                           (
                               UserID int
                               ,MatchingID int
                               ,MatchingName nvarchar(100)
                               ,MatchingTypeCode int
                               ,MatchingTypeName nvarchar(50)
                               ,MatchingTypeName_ru nvarchar(50)


                           )
AS
begin
    if ((@UserID is null) and (@Login is null))
        return;

    insert into @UserMatchings
    (
        UserID
    ,MatchingID
    ,MatchingName
    ,MatchingTypeCode
    ,MatchingTypeName
    ,MatchingTypeName_ru
    )
    select distinct
        [User].UserID

                  ,Match.MatchingID
                  ,Match.MatchingName

                  ,MatchType.MatchingTypeCode
                  ,MatchType.MatchingTypeName
                  ,MatchType.MatchingTypeName_ru

    from
        dbo.Users [User] with (nolock)

            join dbo.Users_Roles UserRole with (nolock) on
                UserRole.UserID = [User].UserID

            join dbo.Matching Match with (nolock) on
                Match.MatchingID = UserRole.MatchingID

            join dbo.MatchingType MatchType with (nolock) on
                MatchType.MatchingTypeID = Match.MatchingTypeID
    where
            [User].UserID = coalesce(@UserID, [User].UserID)
      and
            [User].[Login] = coalesce(@Login, [User].[Login])
    ;

    return;

end
GO
/****** Object:  UserDefinedFunction [napp].[get_UserPasswordHash]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 12.02.2020
-- Update date: 01.03.2020
-- Description:	Возвращает хэш паролья по логину пользователя
-- =============================================
CREATE FUNCTION [napp].[get_UserPasswordHash]
(
    @Login nvarchar (50)
)
    RETURNS nvarchar (max)
AS
BEGIN
    declare
        @Hash nvarchar (max)
    ;

    set @Hash =
            (
                select top 1
                    u.PasswordHash
                from
                    dbo.Users u
                where
                        u.[Login] = @Login
            )
    ;

    if (@Hash is not null)
        return @Hash;

    return '-1';


END

GO
/****** Object:  UserDefinedFunction [napp].[get_UserRoles]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 31.01.2020
-- Update date: 11.02.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_UserRoles]
(
    @UserID int = null
,@Login nvarchar(50) = null
)
    RETURNS @UserRoles TABLE
                       (
                           UserID int
                           ,RoleCode int
                           ,RoleName nvarchar(50)
                           ,RoleName_ru nvarchar(50)

                       )
AS
begin

    if ((@UserID is null) and (@Login is null))
        return;

    insert into @UserRoles
    (
        UserID
    ,RoleCode
    ,RoleName
    ,RoleName_ru
    )
    select distinct
        [User].UserID
                  ,[Role].RoleCode
                  ,[Role].RoleName
                  ,[Role].RoleName_ru

    from
        dbo.Users [User] with (nolock)

            join dbo.Users_Roles UserRole with (nolock) on
                UserRole.UserID = [User].UserID

            join dbo.Roles [Role] with (nolock) on
                [Role].RoleID = UserRole.RoleID

    where
            [User].UserID = coalesce(@UserID, [User].UserID)
      and
            [User].[Login] = coalesce(@Login, [User].[Login])
    ;

    return;

end
GO
/****** Object:  UserDefinedFunction [napp].[get_UserRolesMatchings]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 31.01.2020
-- Update date: 04.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_UserRolesMatchings]
(
    @UserID int = null
,@Login nvarchar(50) = null
)
    RETURNS @UserRolesMatchings TABLE
                                (
                                    UserID int
                                    ,RoleCode int
                                    ,RoleName nvarchar(50)
                                    ,RoleName_ru nvarchar(50)
                                    ,MatchingID int
                                    ,MatchingName nvarchar(100)
                                    ,MatchingTypeCode int
                                    ,MatchingTypeName nvarchar(50)
                                    ,MatchingTypeName_ru nvarchar(50)
                                    ,TutorID int
                                    ,StudentID int

                                )
AS
begin

    if ((@UserID is null) and (@Login is null))
        return;

    insert into @UserRolesMatchings
    (
        UserID
    ,RoleCode
    ,RoleName
    ,RoleName_ru
    ,MatchingID
    ,MatchingName
    ,MatchingTypeCode
    ,MatchingTypeName
    ,MatchingTypeName_ru
    ,TutorID
    ,StudentID
    )
    select
        [User].UserID

         ,[Role].RoleCode
         ,[Role].RoleName
         ,[Role].RoleName_ru

         ,Match.MatchingID
         ,Match.MatchingName

         ,MatchType.MatchingTypeCode
         ,MatchType.MatchingTypeName
         ,MatchType.MatchingTypeName_ru

         ,UserRole.TutorID
         ,UserRole.StudentID

    from
        dbo.Users [User] with (nolock)
            join dbo.Users_Roles UserRole with (nolock) on
                UserRole.UserID = [User].UserID
            join dbo.Roles [Role] with (nolock) on
                [Role].RoleID = UserRole.RoleID
            left join dbo.Matching Match with (nolock) on
                Match.MatchingID = UserRole.MatchingID
            left join dbo.MatchingType MatchType with (nolock) on
                MatchType.MatchingTypeID = Match.MatchingTypeID

    where
            [User].UserID = coalesce(@UserID, [User].UserID)
      and
            [User].[Login] = coalesce(@Login, [User].[Login])
    ;

    return;

end


GO
/****** Object:  UserDefinedFunction [napp_in].[get_agg_AvailableGroups_Name_ByProject]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 21.02.2020
-- Update date: 13.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp_in].[get_agg_AvailableGroups_Name_ByProject]
(
    @ProjectID int
    --,@MatchingID int = null
)
    RETURNS nvarchar(max)
AS
begin

    declare @GroupName_List dbo.StrList;

    insert into @GroupName_List
    (
        value
    )
    select
        GroupName
    from
        --[napp_in].[get_AvailableGroups_ByProject] 
        --	(@ProjectID, @MatchingID) 
        dbo.Projects p with (nolock)

            join dbo.Projects_Groups pg  with (nolock) on
                pg.ProjectID = p.ProjectID

            join dbo.[Groups] g with (nolock) on
                g.GroupID = pg.GroupID

    where
            p.ProjectID = @ProjectID
    ;

    return (select [dbo].[agg_StrList](@GroupName_List, ', ')) ;

end



GO
/****** Object:  UserDefinedFunction [napp_in].[get_agg_Technologies_NameRu_ByProject]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 21.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp_in].[get_agg_Technologies_NameRu_ByProject]
(
    @ProjectID int
    --,@MatchingID int = null
)
    RETURNS nvarchar(max)
AS
begin

    declare @TechnologyName_List dbo.StrList;

    insert into @TechnologyName_List
    (
        value
    )
    select
        tech.TechnologyName_ru
    from
        dbo.Projects_Technologies p with (nolock)

            join dbo.Technologies tech  with (nolock) on
                tech.TechnologyID = p.TechnologyID
    where
            p.ProjectID = @ProjectID
    ;

    return (select [dbo].[agg_StrList](@TechnologyName_List, ', ')) ;

end




GO
/****** Object:  UserDefinedFunction [napp_in].[get_agg_Technologies_NameRu_ByStudent]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp_in].[get_agg_Technologies_NameRu_ByStudent]
(
    @StudentID int
)
    RETURNS nvarchar(max)
AS
begin

    declare @TechnologyName_List dbo.StrList;

    insert into @TechnologyName_List
    (
        value
    )
    select
        tech.TechnologyName_ru
    from
        dbo.Students_Technologies s with (nolock)

            join dbo.Technologies tech  with (nolock) on
                tech.TechnologyID = s.TechnologyID
    where
            s.StudentID = @StudentID
    ;

    return (select [dbo].[agg_StrList](@TechnologyName_List, ', ')) ;

end





GO
/****** Object:  UserDefinedFunction [napp_in].[get_agg_WorkDirections_NameRu_ByProject]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 21.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp_in].[get_agg_WorkDirections_NameRu_ByProject]
(
    @ProjectID int
    --,@MatchingID int = null
)
    RETURNS nvarchar(max)
AS
begin

    declare @WorkDirectionName_List dbo.StrList;

    insert into @WorkDirectionName_List
    (
        value
    )
    select
        wd.DirectionName_ru
    from
        dbo.Projects_WorkDirections p with (nolock)

            join dbo.WorkDirections wd  with (nolock) on
                wd.DirectionID = p.DirectionID
    where
            p.ProjectID = @ProjectID
    ;

    return (select [dbo].[agg_StrList](@WorkDirectionName_List, ', ')) ;

end




GO
/****** Object:  UserDefinedFunction [napp_in].[get_agg_WorkDirections_NameRu_ByStudent]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp_in].[get_agg_WorkDirections_NameRu_ByStudent]
(
    @StudentID int
    --,@MatchingID int = null
)
    RETURNS nvarchar(max)
AS
begin

    declare @WorkDirectionName_List dbo.StrList;

    insert into @WorkDirectionName_List
    (
        value
    )
    select
        wd.DirectionName_ru
    from
        dbo.Students_WorkDirections s with (nolock)

            join dbo.WorkDirections wd  with (nolock) on
                wd.DirectionID = s.DirectionID
    where
            s.StudentID = @StudentID
    ;

    return (select [dbo].[agg_StrList](@WorkDirectionName_List, ', ')) ;

end





GO
/****** Object:  UserDefinedFunction [napp_in].[get_CurrentStageCode_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 13.02.2020
-- Update date: 
-- Description:	Возвращает номер этапа 
-- =============================================
CREATE FUNCTION [napp_in].[get_CurrentStageCode_ByMatching]
(
    @MatchingID int
)
    RETURNS int
AS
BEGIN
    declare
        @CurrentStageCode int
    ;

    set @CurrentStageCode =
            (
                select top 1
                    StageType.StageTypeCode
                from
                    dbo.Stages Stage with (nolock)

                        join dbo.StagesTypes StageType with (nolock) on
                            StageType.StageTypeID = Stage.StageTypeID

                where
                        Stage.MatchingID = @MatchingID
                  and
                        Stage.IsCurrent = 1 -- true
            )
    ;

    if (@CurrentStageCode is not null)
        return @CurrentStageCode;

    return -1;


END

GO
/****** Object:  UserDefinedFunction [napp_in].[get_CurrentStageID_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 19.02.2020
-- Update date: 
-- Description:	Возвращает ID этапа 
-- =============================================
CREATE FUNCTION [napp_in].[get_CurrentStageID_ByMatching]
(
    @MatchingID int
)
    RETURNS int
AS
BEGIN
    declare
        @CurrentStageID int
    ;

    set @CurrentStageID =
            (
                select top 1
                    Stage.StageID
                from
                    dbo.Stages Stage with (nolock)

                where
                        Stage.MatchingID = @MatchingID
                  and
                        Stage.IsCurrent = 1 -- true
            )
    ;

    if (@CurrentStageID is not null)
        return @CurrentStageID;

    return -1;


END


GO
/****** Object:  Table [dbo].[Students]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Students](
                                 [StudentID] [int] IDENTITY(1,1) NOT NULL,
                                 [StudentBK] [int] NULL,
                                 [GroupID] [int] NOT NULL,
                                 [Info] [nvarchar](max) NULL,
                                 [MatchingID] [int] NULL,
                                 [Info2] [nvarchar](250) NULL,
                                 CONSTRAINT [PK_Students] PRIMARY KEY CLUSTERED
                                     (
                                      [StudentID] ASC
                                         )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StudentsPreferences]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StudentsPreferences](
                                            [PreferenceID] [int] IDENTITY(1,1) NOT NULL,
                                            [StudentID] [int] NOT NULL,
                                            [ProjectID] [int] NOT NULL,
                                            [OrderNumber] [smallint] NOT NULL,
                                            [IsAvailable] [bit] NOT NULL,
                                            [TypeID] [int] NULL,
                                            [IsInUse] [bit] NULL,
                                            [IsUsed] [bit] NULL,
                                            [CreateDate] [datetime] NULL,
                                            CONSTRAINT [PK_StudentsPreferences] PRIMARY KEY CLUSTERED
                                                (
                                                 [PreferenceID] ASC
                                                    )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Users_Roles]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users_Roles](
                                    [UserRoleID] [int] IDENTITY(1,1) NOT NULL,
                                    [UserID] [int] NOT NULL,
                                    [RoleID] [int] NOT NULL,
                                    [MatchingID] [int] NULL,
                                    [LastVisitDate] [datetime] NULL,
                                    [StudentID] [int] NULL,
                                    [TutorID] [int] NULL,
                                    CONSTRAINT [PK_Users_Roles] PRIMARY KEY CLUSTERED
                                        (
                                         [UserRoleID] ASC
                                            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Tutors]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tutors](
                               [TutorID] [int] IDENTITY(1,1) NOT NULL,
                               [TutorBK] [int] NULL,
                               [IsClosed] [bit] NOT NULL,
                               [CloseIterationNumber] [smallint] NULL,
                               [IsReadyToStart] [bit] NULL,
                               [MatchingID] [int] NULL,
                               CONSTRAINT [PK_Tutors] PRIMARY KEY CLUSTERED
                                   (
                                    [TutorID] ASC
                                       )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Users]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Users](
                              [UserID] [int] IDENTITY(1,1) NOT NULL,
                              [Login] [nvarchar](50) NOT NULL,
                              [PasswordHash] [nvarchar](max) NULL,
                              [LastVisitDate] [datetime] NULL,
                              [UserBK] [int] NULL,
                              [Email] [nvarchar](50) NULL,
                              [Name] [nvarchar](100) NULL,
                              [Surname] [nvarchar](100) NULL,
                              [Patronimic] [nvarchar](100) NULL,
                              CONSTRAINT [PK_Users] PRIMARY KEY CLUSTERED
                                  (
                                   [UserID] ASC
                                      )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo_v].[Tutors]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 12.02.2020
-- Update date: 07.03.2020
-- Description:	
-- =============================================
CREATE view [dbo_v].[Tutors]
as
select
    Tutor.TutorID
     ,Tutor.IsClosed
     ,Tutor.IsReadyToStart
     ,[User].UserID
     ,UserRole.MatchingID
     ,[User].Surname
     ,[User].Name
     ,[User].Patronimic
     ,UserRole.LastVisitDate

     ,[User].Surname
    + ' ' + iif ([User].Name is not null, substring([User].Name,1, 1) , '' ) + '.'
    + ' ' + iif ([User].Patronimic is not null, substring([User].Patronimic,1, 1) , '' ) + '.'
    as NameAbbreviation

from
    dbo.Tutors Tutor with (nolock)

        join dbo.Users_Roles UserRole with (nolock) on
            UserRole.TutorID = Tutor.TutorID

        join dbo.Users [User] (nolock) on
            [User].UserID = UserRole.UserID





GO
/****** Object:  Table [dbo].[Projects]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Projects](
                                 [ProjectID] [int] IDENTITY(1,1) NOT NULL,
                                 [ProjectName] [nvarchar](200) NULL,
                                 [Info] [nvarchar](max) NULL,
                                 [TutorID] [int] NOT NULL,
                                 [IsClosed] [bit] NULL,
                                 [IsDefault] [bit] NULL,
                                 [MatchingID] [int] NULL,
                                 [ProjectQuotaQty] [smallint] NULL,
                                 [CloseStage] [int] NULL,
                                 [CloseDate] [datetime] NULL,
                                 [CreateDate] [datetime] NULL,
                                 [UpdateDate] [datetime] NULL,
                                 [ProjectQuotaDelta] [smallint] NULL,
                                 CONSTRAINT [PK_Projects] PRIMARY KEY CLUSTERED
                                     (
                                      [ProjectID] ASC
                                         )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  View [dbo_v].[Projects]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO









CREATE view [dbo_v].[Projects]
as

select
    Project.TutorID
     ,Tutor.UserID
     ,Tutor.Surname		as TutorSurname
     ,Tutor.Name			as TutorName
     ,Tutor.Patronimic	as TutorPatronimic
     ,Tutor.NameAbbreviation as TutorNameAbbreviation
     ,Tutor.IsClosed		as Tutor_IsClosed

     ,Project.ProjectID
--,iif (Project.IsDefault = 1, 'Записаться к преподавателю' ,Project.ProjectName) as ProjectName
     ,Project.ProjectName as ProjectName
     ,Project.Info
     ,Project.IsClosed
     ,Project.IsDefault

     ,Project.MatchingID

--,ProjectQuota.Qty as Qty
     ,Project.ProjectQuotaQty as Qty
     ,iif(	Project.ProjectQuotaQty is not null
    ,cast(Project.ProjectQuotaQty as nvarchar (50))
    ,'Не важно') as QtyDescription

     ,[napp_in].[get_agg_AvailableGroups_Name_ByProject] (Project.ProjectID) as AvailableGroupsName_List
     ,[napp_in].[get_agg_Technologies_NameRu_ByProject] (Project.ProjectID) as TechnologiesName_List
     ,[napp_in].[get_agg_WorkDirections_NameRu_ByProject] (Project.ProjectID) as WorkDirectionsName_List


from
    dbo.Projects Project with (nolock)

        join dbo_v.Tutors Tutor on
            Tutor.TutorID = Project.TutorID

--join dbo_v.ActiveQuotas ProjectQuota on 
--	 ProjectQuota.ProjectID = Project.ProjectID
--	 and 
--	 ProjectQuota.GroupID is null 
--	 and 
--	 ProjectQuota.IsCommon = 0 -- false
;









GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage3_Student_Projects]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create function [napp].[get_StatisticStage3_Student_Projects]
(
    @MatchingID int
,@StudentID int
)
    RETURNS TABLE
        as
        return
        SELECT
            StudentsPreferences.ProjectID				as StudentsPreferencesProjectID
             ,dbo_v.Projects.ProjectName					as ProjectsProjectName
             ,dbo_v.Projects.TechnologiesName_List		as ProjectsTechnologiesName_List
             ,dbo_v.Projects.WorkDirectionsName_List		as ProjectsWorkDirectionsName_List
             ,Qty										as ProjectQty
             ,dbo_v.Projects.AvailableGroupsName_List	as ProjectsAvailableGroupsName_List
        FROM
            StudentsPreferences with(nolock)
                JOIN Students ON StudentsPreferences.StudentID = Students.StudentID
                JOIN dbo_v.Projects ON Projects.ProjectID = StudentsPreferences.ProjectID
        WHERE Students.MatchingID = @MatchingID
          AND Students.StudentID = @StudentID
GO
/****** Object:  Table [dbo].[CommonQuotas]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CommonQuotas](
                                     [CommonQuotaID] [int] IDENTITY(1,1) NOT NULL,
                                     [TutorID] [int] NULL,
                                     [Qty] [smallint] NULL,
                                     [CreateDate] [datetime] NOT NULL,
                                     [QuotaStateID] [int] NOT NULL,
                                     [UpdateDate] [datetime] NULL,
                                     [IsNotification] [bit] NULL,
                                     [Message] [nvarchar](250) NULL,
                                     [StageID] [int] NULL,
                                     CONSTRAINT [PK_CommonQuotas] PRIMARY KEY CLUSTERED
                                         (
                                          [CommonQuotaID] ASC
                                             )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Stages]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Stages](
                               [StageID] [int] IDENTITY(1,1) NOT NULL,
                               [StageTypeID] [int] NOT NULL,
                               [StageName] [nvarchar](100) NULL,
                               [IterationNumber] [smallint] NULL,
                               [StartDate] [datetime] NULL,
                               [EndPlanDate] [datetime] NULL,
                               [EndDate] [datetime] NULL,
                               [IsCurrent] [bit] NOT NULL,
                               [MatchingID] [int] NOT NULL,
                               CONSTRAINT [PK_StagesIterations] PRIMARY KEY CLUSTERED
                                   (
                                    [StageID] ASC
                                       )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[QuotasStates]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[QuotasStates](
                                     [QuotaStateID] [int] IDENTITY(1,1) NOT NULL,
                                     [QuotaStateCode] [int] NOT NULL,
                                     [QuotaStateName] [nvarchar](50) NOT NULL,
                                     [QuotaStateName_ru] [nvarchar](50) NULL,
                                     CONSTRAINT [PK_QuotasStates] PRIMARY KEY CLUSTERED
                                         (
                                          [QuotaStateID] ASC
                                             )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[StagesTypes]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StagesTypes](
                                    [StageTypeID] [int] IDENTITY(1,1) NOT NULL,
                                    [StageTypeCode] [int] NOT NULL,
                                    [StageTypeName] [nvarchar](50) NOT NULL,
                                    [StageTypeName_ru] [nvarchar](50) NULL,
                                    CONSTRAINT [PK_StagesTypes] PRIMARY KEY CLUSTERED
                                        (
                                         [StageTypeID] ASC
                                            )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_CommonQuota_History_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.02.2020
-- Update date: 13.03.2020
-- Description:	История запросов общей квоты по преподавателю
-- =============================================
CREATE FUNCTION [napp].[get_CommonQuota_History_ByTutor]
(
    @TutorID int
)
    RETURNS  TABLE
        as
        return
        select
            Quota.CommonQuotaID as QuotaID
             ,Quota.CreateDate
             ,Quota.UpdateDate
             ,Quota.Qty
             ,Quota.Message
             ,Quota.IsNotification
             ,QuotaState.QuotaStateCode
             ,QuotaState.QuotaStateName
             ,QuotaState.QuotaStateName_ru
             ,Stage.StageID
             ,Stage.StageName
             ,StageType.StageTypeCode
             ,StageType.StageTypeName
             ,StageType.StageTypeName_ru
             ,Stage.IterationNumber

        from
            dbo.CommonQuotas Quota with (nolock)

                join dbo.QuotasStates QuotaState with (nolock) on
                    QuotaState.QuotaStateID = Quota.QuotaStateID

                join dbo.Stages [Stage] with (nolock) on
                    [Stage].StageID = Quota.StageID

                join dbo.StagesTypes StageType with (nolock) on
                    StageType.StageTypeID = [Stage].StageTypeID

        where
                Quota.TutorID = @TutorID






GO
/****** Object:  UserDefinedFunction [napp].[get_CommonQuota_Request_Notification_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 24.02.2020
-- Update date: 04.04.2020
-- Description:	Выводит уведомление для преподавателя, если оно есть 
-- =============================================
CREATE FUNCTION [napp].[get_CommonQuota_Request_Notification_ByTutor]
(
    @TutorID int
)
    RETURNS  TABLE
        as
        return
        select
            Quota.QuotaID
             ,Quota.Qty
             ,Quota.QuotaStateCode
             ,Quota.QuotaStateName
             ,Quota.QuotaStateName_ru

             ,Quota.CreateDate
             ,Quota.UpdateDate

        from
            [napp].[get_CommonQuota_History_ByTutor]( @TutorID) Quota

        where
                Quota.IsNotification = 1
          and
--Quota.QuotaStateName = 'requested'
                Quota.QuotaStateName in ('active', 'declined')






GO
/****** Object:  View [dbo_v].[ActiveCommonQuotas]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- Возвращает действительную общую квот преподавателей 
CREATE view [dbo_v].[ActiveCommonQuotas]
as
select
    Quota.*
from
    dbo.CommonQuotas Quota with (nolock)

        join dbo.QuotasStates QuotaState with (nolock) on
            QuotaState.QuotaStateID = Quota.QuotaStateID

where
        QuotaState.QuotaStateCode = 1 --active



GO
/****** Object:  Table [dbo].[TutorsChoice]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[TutorsChoice](
                                     [ChoiceID] [int] IDENTITY(1,1) NOT NULL,
                                     [StudentID] [int] NOT NULL,
                                     [ProjectID] [int] NOT NULL,
                                     [SortOrderNumber] [smallint] NULL,
                                     [IsInQuota] [bit] NOT NULL,
                                     [IsChangeble] [bit] NULL,
                                     [TypeID] [int] NOT NULL,
                                     [PreferenceID] [int] NULL,
                                     [IterationNumber] [smallint] NULL,
                                     [StageID] [int] NOT NULL,
                                     [CreateDate] [datetime] NULL,
                                     [UpdateDate] [datetime] NULL,
                                     [IsFromPreviousIteration] [bit] NULL,
                                     CONSTRAINT [PK_TutorsMatching] PRIMARY KEY CLUSTERED
                                         (
                                          [ChoiceID] ASC
                                             )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[ChoosingTypes]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ChoosingTypes](
                                      [TypeID] [int] IDENTITY(1,1) NOT NULL,
                                      [TypeCode] [int] NOT NULL,
                                      [TypeName] [nvarchar](50) NOT NULL,
                                      [TypeName_ru] [nvarchar](50) NULL,
                                      CONSTRAINT [PK_ChoosingTypes] PRIMARY KEY CLUSTERED
                                          (
                                           [TypeID] ASC
                                              )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage4_Tutors]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION [napp].[get_StatisticStage4_Tutors]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        select
            Tutor.TutorID				AS TutorID
             ,Tutor.Name					AS TutorName
             ,Tutor.Surname				AS TutorSurname
             ,Tutor.Patronimic			AS TutorPatronimic
             ,Tutor.NameAbbreviation		AS TutorNameAbbreviation
             ,Quota.Qty					AS TutorQuotaQty
             ,Tutor.LastVisitDate		AS TutorLastVisitDate

             ,count(distinct Project.ProjectID)  as TutorProjectsAllCount		-- Êîëè÷åñòâî ïðîåêòîâ
             ,count(distinct case when Project.IsClosed = 1 then Project.ProjectID end)  as TutorProjectsClosedCount -- Ïðîåêòîâ çàêðûòî

             ,iif (count(case when CType.TypeName = 'Self' then Choice.ChoiceID end) > 0, 1, 0) as TutorIsSelfChoice --Ñàìîñòîÿòåëüíûé ëè âûáîð
             ,iif (count(case when Choice.IsInQuota = 0 then Choice.ChoiceID end) > 0, 1, 0) as TutorIsAvailableChoice--Åñòü ëè Âûáîð

             ,count(case when Choice.IsInQuota = 1 then Choice.ChoiceID end) as TutorStudentsInQuotaCount -- Ñòóäåíòîâ â êâîòå
             ,count(case when Choice.IsInQuota = 0 then Choice.ChoiceID end) as TutorStudentsOutQuotaCount-- Ñòóäåíòîâ íå â êâîòå 


        from
            dbo_v.Tutors Tutor with (nolock)

                join dbo_v.ActiveCommonQuotas Quota with (nolock) on
                    Quota.TutorID = Tutor.TutorID

                left join dbo.Projects Project with (nolock) on
                    Project.TutorID = Tutor.TutorID

                left join dbo.TutorsChoice Choice with (nolock) on
                        Choice.ProjectID = Project.ProjectID
                    and
                        Choice.StageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID)

                left join dbo.ChoosingTypes CType with (nolock) on
                    CType.TypeID = Choice.TypeID

        where
                Tutor.MatchingID = @MatchingID

        group by
            Tutor.TutorID
               ,Tutor.Name
               ,Tutor.Surname
               ,Tutor.Patronimic
               ,Tutor.NameAbbreviation
               ,Tutor.IsReadyToStart
               ,Quota.Qty
               ,Tutor.LastVisitDate

GO
/****** Object:  Table [dbo].[Matching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Matching](
                                 [MatchingID] [int] IDENTITY(1,1) NOT NULL,
                                 [MatchingName] [nvarchar](100) NOT NULL,
                                 [MatchingTypeID] [int] NULL,
                                 [CreatorUserID] [int] NULL,
                                 CONSTRAINT [PK_Matching] PRIMARY KEY CLUSTERED
                                     (
                                      [MatchingID] ASC
                                         )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_CurrentStage_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 13.02.2020
-- Update date: 14.05.2020
-- Description:	Описание текущего состояния распределения. 
--				Название и код этапа, дата начала и плановая дата окончания  этапа, номер итерации, это этап  Итераций
--				Название распределения
-- =============================================
CREATE FUNCTION [napp].[get_CurrentStage_ByMatching]
(
    @MatchingID int
)
    RETURNS table
        as
        return

        select top 1
            Stage.StageID
                   ,Stage.StageName
                   ,Stage.StartDate
                   ,Stage.EndPlanDate
                   ,Stage.IterationNumber

                   ,StagesType.StageTypeID
                   ,StagesType.StageTypeCode
                   ,StagesType.StageTypeName
                   ,StagesType.StageTypeName_ru

                   ,Matching.MatchingID
                   ,Matching.MatchingName


        from
            dbo.Matching Matching with (nolock)

                join dbo.Stages Stage with (nolock) on
                    Stage.MatchingID = Matching.MatchingID

                join dbo.StagesTypes StagesType with (nolock) on
                    StagesType.StageTypeID = Stage.StageTypeID

        where
                Matching.MatchingID = @MatchingID
          and
                Stage.IsCurrent = 1 -- true



GO
/****** Object:  View [dbo_v].[Allocation]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE view [dbo_v].[Allocation]
as
select
    MatchingStage.MatchingID
     ,MatchingStage.StageTypeID
     ,MatchingStage.StageTypeCode
     ,MatchingStage.StageTypeName
     ,MatchingStage.StageTypeName_ru
     ,Student.StudentID
     ,Student.GroupID
     ,TutorsChoice.ChoiceID
     ,TutorsChoice.ProjectID
     ,TutorsChoice.SortOrderNumber
     ,TutorsChoice.PreferenceID
     ,iif(TutorsChoice.ChoiceID is not null, 1, 0) as IsAllocated
     ,ChoosingType.TypeID
     ,ChoosingType.TypeCode
     ,ChoosingType.TypeName
     ,ChoosingType.TypeName_ru

from
    dbo.Students as Student with (nolock)

        cross apply
    (
        select
            *
        from
            napp.get_CurrentStage_ByMatching (Student.MatchingID) Stage

    ) as MatchingStage

        left join dbo.TutorsChoice as TutorsChoice with (nolock) on
                TutorsChoice.StudentID = Student.StudentID
            and
                TutorsChoice.StageID = MatchingStage.StageID
            and
                TutorsChoice.IsInQuota = 1	-- Убрано условие по этапу и добавлено это, чтобы на каждой интерацц смотреть кто распределен. 
    -- Дополнительно нужно раскашивать признаком закрыт или нет проект

        left join dbo.ChoosingTypes as ChoosingType with (nolock) on
            ChoosingType.TypeID = TutorsChoice.TypeID



--where 
--MatchingStage.StageTypeCode in (5, 6)


--left join dbo.TutorsChoice TutorsChoice with (nolock) 
GO
/****** Object:  Table [dbo].[Groups]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Groups](
                               [GroupID] [int] IDENTITY(1,1) NOT NULL,
                               [GroupBK] [int] NULL,
                               [GroupName] [nvarchar](100) NOT NULL,
                               [MatchingID] [int] NULL,
                               CONSTRAINT [PK_Groups] PRIMARY KEY CLUSTERED
                                   (
                                    [GroupID] ASC
                                       )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Roles]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Roles](
                              [RoleID] [int] IDENTITY(1,1) NOT NULL,
                              [RoleCode] [int] NULL,
                              [RoleName] [nvarchar](50) NULL,
                              [RoleType] [smallint] NULL,
                              [RoleName_ru] [nvarchar](50) NULL,
                              CONSTRAINT [PK_Roles] PRIMARY KEY CLUSTERED
                                  (
                                   [RoleID] ASC
                                      )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  View [dbo_v].[Students]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO








-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 11.02.2020
-- Update date: 30.11.2020
-- Description:	
-- =============================================
CREATE view [dbo_v].[Students]
as
select
    Student.StudentID
     ,[Group].GroupID
     ,[Group].GroupName
     ,[User].UserID
     ,UserRole.MatchingID
     ,[User].Surname
     ,[User].Name
     ,[User].Patronimic
     ,[User].Surname
    + ' ' + iif ([User].Name is not null, substring([User].Name,1, 1) , '' ) + '.'
    + ' ' + iif ([User].Patronimic is not null, substring([User].Patronimic,1, 1) , '' ) + '.'
                                                                             as NameAbbreviation

     ,UserRole.LastVisitDate
     ,Student.Info
     ,Student.Info2
     ,[napp_in].[get_agg_WorkDirections_NameRu_ByStudent](Student.StudentID) as WorkDirectionsName_List
     ,[napp_in].[get_agg_Technologies_NameRu_ByStudent] (Student.StudentID) as TechnologiesName_List

from
    dbo.Students Student with (nolock)

        join dbo.Groups [Group] with (nolock) on
            [Group].GroupID = Student.GroupID

        join dbo.Users_Roles UserRole with (nolock) on
            UserRole.StudentID = Student.StudentID

        join dbo.Users [User] (nolock) on
            [User].UserID = UserRole.UserID

        join dbo.Roles [Role] (nolock) on
                [Role].RoleID = UserRole.RoleID
            and
                [Role].RoleType = 1 -- Тип роли = бизнес роль 
            and
                [Role].RoleCode = 2 -- Роль = студент










GO
/****** Object:  View [dbo_v].[Allocation_FullInfo]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [dbo_v].[Allocation_FullInfo]
as
select
    Allocation.MatchingID
     ,Allocation.StageTypeID
     ,Allocation.StageTypeCode
     ,Allocation.StageTypeName
     ,Allocation.StageTypeName_ru

     ,Student.StudentID
     ,Student.[Name]				as StudentName
     ,Student.Surname			as StudentSurname
     ,Student.Patronimic			as StudentPatronimic
     ,Student.NameAbbreviation	as StudentNameAbbreviation
     ,Student.GroupID
     ,Student.GroupName

     ,Allocation.IsAllocated
     ,Allocation.ChoiceID
     ,Allocation.PreferenceID
     ,Allocation.SortOrderNumber

     ,Project.ProjectID
     ,Project.ProjectName
     ,Project.TutorID
     ,Project.TutorName
     ,Project.TutorSurname
     ,Project.TutorPatronimic
     ,Project.TutorNameAbbreviation

     ,Allocation.TypeID
     ,Allocation.TypeCode
     ,Allocation.TypeName
     ,Allocation.TypeName_ru



from
    dbo_v.Allocation as Allocation with(nolock)

        left join dbo_v.Students as Student  with(nolock)  on
            Student.StudentID =   Allocation.StudentID

        left join dbo_v.Projects as Project with(nolock)  on
            Project.ProjectID = Allocation.ProjectID

GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage4_Tutors_Project_Allocated]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [napp].[get_StatisticStage4_Tutors_Project_Allocated]
(
    @MatchingID int,
    @TutorID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            StudentNameAbbreviation		AS Allocation_FullInfoStudentNameAbbreviation
             --,StudentID						AS Allocation_FullInfoStudentID
             --,ProjectID						AS Allocation_FullInfoProjectID
             ,ProjectName					AS Allocation_FullInfoProjectName
             ,TypeName_ru					AS Allocation_FullInfoTypeName_ru


        from dbo_v.Allocation_FullInfo with(nolock)
        WHERE dbo_v.Allocation_FullInfo.MatchingID = @MatchingID
          AND dbo_v.Allocation_FullInfo.TutorID = @TutorID
GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage4_Students]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION [napp].[get_StatisticStage4_Students]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        select
            Student.StudentID						AS StudentID
             ,Student.Name							AS StudentName
             ,Student.Surname						AS StudentSurname
             ,Student.Patronimic						AS StudentPatronimic
             ,Student.NameAbbreviation				AS StudentNameAbbreviation
             ,Student.LastVisitDate					AS StudentLastVisitDate
             ,Student.GroupID						AS StudentGroupID
             ,Student.GroupName						AS StudentGroupName

             ,iif(Project.IsClosed = 1, 1, 0) as ProjectIsAllocated
             ,iif(Choice.IsInQuota = 1, 1, 0) as ChoiceIsInQuota
             ,iif(Choice.IsInQuota = 0, 1, 0) as ChoiceIsOutQuota
             ,iif(Choice.ChoiceID is null, 1, 0) as ChoiceIsCantAllocated

             ,PreferenceType.TypeCode				AS PreferenceTypeTypeCode
             ,PreferenceType.TypeName				AS PreferenceTypeTypeName
             ,PreferenceType.TypeName_ru				AS PreferenceTypeTypeName_ru

        from
            dbo_v.Students Student with (nolock)

                left join dbo.TutorsChoice Choice with (nolock) on
                        Choice.StudentID = Student.StudentID
                    and
                        Choice.StageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID)

                left join dbo.Projects Project with (nolock) on
                    Project.ProjectID = Choice.ProjectID

                left join dbo.StudentsPreferences Preference with (nolock) on
                    Preference.PreferenceID = Choice.PreferenceID

                left join dbo.ChoosingTypes PreferenceType with (nolock) on
                    PreferenceType.TypeID = Preference.TypeID
        where
                Student.MatchingID = @MatchingID
GO
/****** Object:  Table [dbo].[Students_WorkDirections]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Students_WorkDirections](
                                                [StudentDirectionID] [int] IDENTITY(1,1) NOT NULL,
                                                [StudentID] [int] NOT NULL,
                                                [DirectionID] [int] NOT NULL,
                                                CONSTRAINT [PK_StudentsDirections] PRIMARY KEY CLUSTERED
                                                    (
                                                     [StudentDirectionID] ASC
                                                        )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Students_Technologies]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Students_Technologies](
                                              [StudentTechnologyID] [int] IDENTITY(1,1) NOT NULL,
                                              [StudentID] [int] NOT NULL,
                                              [TechnologyID] [int] NOT NULL,
                                              CONSTRAINT [PK_StudentsTechnologies] PRIMARY KEY CLUSTERED
                                                  (
                                                   [StudentTechnologyID] ASC
                                                      )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage3_Students]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION [napp].[get_StatisticStage3_Students]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Student.StudentID				as StudentID
             ,Student.Name					as StudentName
             ,Student.Surname				as StudentSurname
             ,Student.Patronimic				as StudentPatronimic
             ,Student.NameAbbreviation		as StudentNameAbbreviation
             ,Student.LastVisitDate			as StudentLastVisitDate

             ,iif(Student.Info is not null, 1, 0) as IsSetInfo
             ,iif(count(Technology.StudentTechnologyID) > 0, 1, 0) as IsSetTechnologies
             ,iif(count(Direction.StudentDirectionID) > 0, 1, 0) as IsSetWorkDirections

             ,[Group].GroupName				as StudentGroupName

             ,(case
                   when count(Preference.PreferenceID) != 0 then count(Preference.PreferenceID)
                   else '-'
            end
            )								as ProjectCount


        FROM
            dbo_v.Students Student with (nolock)

                join dbo.Groups [Group] with (nolock) on
                    [Group].GroupID = Student.GroupID

                --join dbo_v.Users_FullInfo [User] with (nolock) on 
                --	[User].StudentID = Student.StudentID
                --	and 
                --	[User].MatchingID = @MatchingID
                --	and 
                --	[User].RoleCode = 2

                left join dbo.StudentsPreferences Preference with (nolock) on
                    Preference.StudentID = Student.StudentID

                left join dbo.Students_Technologies Technology with (nolock) on
                    Technology.StudentID = Student.StudentID

                left join dbo.Students_WorkDirections Direction with (nolock) on
                    Direction.StudentID = Student.StudentID

        where
            @MatchingID is not null
          and
                Student.MatchingID = @MatchingID
        group by
            Student.StudentID
               ,Student.Name
               ,Student.Surname
               ,Student.Patronimic
               ,Student.NameAbbreviation
               ,Student.LastVisitDate

               ,[Group].GroupName
               ,Student.Info
GO
/****** Object:  View [dbo_v].[CommonQuotas]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE view [dbo_v].[CommonQuotas]
as
select
    Tutor.MatchingID
     ,Tutor.TutorID
     ,Tutor.IsReadyToStart
     --,TutorUser.Name
     --,TutorUser.Surname
     --,TutorUser.Patronimic
     --,TutorUser.Surname 
     --		+ ' ' + iif (TutorUser.Name is not null, substring(TutorUser.Name,1, 1) , '' ) + '.'
     --		+ ' ' + iif (TutorUser.Patronimic is not null, substring(TutorUser.Patronimic,1, 1) , '' ) + '.'
     --			as NameAbbreviation  
     ,CommonQuota.CommonQuotaID
     ,CommonQuota.Qty
     ,CommonQuota.CreateDate
     ,CommonQuota.QuotaStateID
     ,CommonQuota.UpdateDate
     ,CommonQuota.IsNotification
     ,CommonQuota.Message
     ,CommonQuota.StageID

     ,Stage.IsCurrent
     ,StageType.StageTypeCode
     ,StageType.StageTypeName
     ,StageType.StageTypeName_ru
     ,Stage.IterationNumber

     ,QuotasState.QuotaStateCode
     ,QuotasState.QuotaStateName
     ,QuotasState.QuotaStateName_ru


from  dbo.CommonQuotas CommonQuota with (nolock)

          join dbo.Tutors Tutor with (nolock) on
        Tutor.TutorID = CommonQuota.TutorID

          join dbo.Stages [Stage] with (nolock) on
        [Stage].StageID = CommonQuota.StageID

          join dbo.StagesTypes StageType with (nolock) on
        StageType.StageTypeID = [Stage].StageTypeID

          join dbo.QuotasStates QuotasState with (nolock) on
        QuotasState.QuotaStateID = CommonQuota.QuotaStateID

--join dbo.Users_Roles TutorUserRole with (nolock) on  
--	TutorUserRole.TutorID = Tutor.TutorID 
--	and 
--	TutorUserRole.MatchingID = Tutor.MatchingID 

--join dbo.Roles TutorRole with (nolock) on
--	TutorUserRole.RoleID = TutorRole.RoleID 
--	and
--	TutorRole.RoleCode = 1 	--Tutor

--join dbo.Users TutorUser with(nolock) on
--	TutorUserRole.UserID = TutorUser.UserID






GO
/****** Object:  UserDefinedFunction [napp].[get_FinishedAllocations]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 25.04.2020
-- Update date: 31.05.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_FinishedAllocations] ()
    RETURNS  TABLE
        as
        return
        select
            Allocation.MatchingID
             ,Allocation.StageTypeID
             ,Allocation.StageTypeCode
             ,Allocation.StageTypeName
             ,Allocation.StageTypeName_ru

             ,Allocation.StudentID
             ,Allocation.StudentName
             ,Allocation.StudentSurname
             ,Allocation.StudentPatronimic
             ,Allocation.StudentNameAbbreviation
             ,Allocation.GroupID
             ,Allocation.GroupName

             ,cast(Allocation.IsAllocated as bit) as IsAllocated
             ,Allocation.ChoiceID
             ,Allocation.PreferenceID
             ,Allocation.SortOrderNumber

             ,Allocation.ProjectID
             ,Allocation.ProjectName
             ,Allocation.TutorID
             ,Allocation.TutorName
             ,Allocation.TutorSurname
             ,Allocation.TutorPatronimic
             ,Allocation.TutorNameAbbreviation

             --,Allocation.TypeID
             --,Allocation.TypeCode
             --,Allocation.TypeName
             --,Allocation.TypeName_ru
        from
            dbo_v.Allocation_FullInfo as Allocation with (nolock)
        where
                Allocation.StageTypeCode = 6



GO
/****** Object:  UserDefinedFunction [napp].[get_Allocation_ByExecutive]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 25.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Allocation_ByExecutive]
(
    @UserID int
,@MatchingID int
)
    RETURNS  TABLE
        as
        return
        select
            Allocation.MatchingID
             ,Allocation.StageTypeID
             ,Allocation.StageTypeCode
             ,Allocation.StageTypeName
             ,Allocation.StageTypeName_ru

             ,Allocation.StudentID
             ,Allocation.StudentName
             ,Allocation.StudentSurname
             ,Allocation.StudentPatronimic
             ,Allocation.StudentNameAbbreviation
             ,Allocation.GroupID
             ,Allocation.GroupName

             ,cast(Allocation.IsAllocated as bit) as IsAllocated
             ,Allocation.ChoiceID
             ,Allocation.PreferenceID
             ,Allocation.SortOrderNumber

             ,Allocation.ProjectID
             ,Allocation.ProjectName
             ,Allocation.TutorID
             ,Allocation.TutorName
             ,Allocation.TutorSurname
             ,Allocation.TutorPatronimic
             ,Allocation.TutorNameAbbreviation

             ,Allocation.TypeID
             ,Allocation.TypeCode
             ,Allocation.TypeName
             ,Allocation.TypeName_ru
        from
            dbo_v.Allocation_FullInfo as Allocation with (nolock)

                join Users_Roles ExecutiveUserRole with (nolock) on
                    ExecutiveUserRole.MatchingID = Allocation.MatchingID

        where
                Allocation.MatchingID = @MatchingID
          and
                ExecutiveUserRole.UserID = @UserID
          and
                ExecutiveUserRole.RoleID = (	select RoleID
                                                from
                                                    dbo.Roles with(nolock)
                                                where
                                                        RoleCode =  3 )--execuеtive


GO
/****** Object:  UserDefinedFunction [napp].[get_FinishedAllocations_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekatherina
-- Create date: 31.05.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_FinishedAllocations_ByMatching]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        select
            Allocation.MatchingID
             ,Allocation.StageTypeID
             ,Allocation.StageTypeCode
             ,Allocation.StageTypeName
             ,Allocation.StageTypeName_ru

             ,Allocation.StudentID
             ,Allocation.StudentName
             ,Allocation.StudentSurname
             ,Allocation.StudentPatronimic
             ,Allocation.StudentNameAbbreviation
             ,Allocation.GroupID
             ,Allocation.GroupName

             ,cast(Allocation.IsAllocated as bit) as IsAllocated
             ,Allocation.ChoiceID
             ,Allocation.PreferenceID
             ,Allocation.SortOrderNumber

             ,Allocation.ProjectID
             ,Allocation.ProjectName
             ,Allocation.TutorID
             ,Allocation.TutorName
             ,Allocation.TutorSurname
             ,Allocation.TutorPatronimic
             ,Allocation.TutorNameAbbreviation

             --,Allocation.TypeID
             --,Allocation.TypeCode
             --,Allocation.TypeName
             --,Allocation.TypeName_ru
        from
            dbo_v.Allocation_FullInfo as Allocation with (nolock)
        where
                Allocation.StageTypeCode = 6
          and
                Allocation.MatchingID = @MatchingID




GO
/****** Object:  UserDefinedFunction [napp].[get_CommonQuota_History_ByExecutive]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 14.03.2020
-- Update date: 05.05.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_CommonQuota_History_ByExecutive]
(
    @UserID int
,@MatchingID int
)
    returns table
        as
        return

        select
            Quota.CommonQuotaID as QuotaID
             ,Quota.TutorID
             ,Tutor.Name
             ,Tutor.Surname
             ,Tutor.Patronimic
             ,Tutor.NameAbbreviation
             ,Quota.Qty as RequestedQuotaQty
             ,Quota.Message
             ,napp.get_CommonQuota_ByTutor(Quota.TutorID) as CurrentQuotaQty
             ,Quota.IsNotification

             ,Quota.QuotaStateCode
             ,Quota.QuotaStateName
             ,Quota.QuotaStateName_ru
             ,Quota.UpdateDate
             ,Quota.CreateDate

             ,Quota.StageID
             ,Quota.StageTypeCode
             ,Quota.StageTypeName
             ,Quota.StageTypeName_ru
             ,Quota.IterationNumber

        from
            dbo_v.CommonQuotas Quota with (nolock)

                join dbo_v.Tutors Tutor with (nolock) on
                    Tutor.TutorID = Quota.TutorID

                join Users_Roles ExecutiveUserRole with (nolock) on
                    ExecutiveUserRole.MatchingID = Quota.MatchingID



        where
--Quota.QuotaStateName = 'requested'
--and
                ExecutiveUserRole.MatchingID = @MatchingID
          and
                ExecutiveUserRole.UserID = @UserID
          and
                ExecutiveUserRole.RoleID = (	select RoleID
                                                from
                                                    dbo.Roles with(nolock)
                                                where
                                                        RoleCode =  3 )--execuеtive



GO
/****** Object:  UserDefinedFunction [napp].[get_Stages_History_ByExecutive]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 28.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Stages_History_ByExecutive]
(
    @UserID int
,@MatchingID int
)
    RETURNS  TABLE
        as
        return
        select
            Stage.StageID

             ,StageType.StageTypeID
             ,StageType.StageTypeCode
             ,StageType.StageTypeName
             ,StageType.StageTypeName_ru

             ,Stage.IterationNumber
             ,Stage.StartDate
             ,Stage.EndPlanDate
             ,Stage.EndDate

             ,Stage.IsCurrent

        from
            dbo.Stages Stage with (nolock)

                left join dbo.StagesTypes StageType with (nolock)  on
                    StageType.StageTypeID = Stage.StageTypeID

                join Users_Roles ExecutiveUserRole with (nolock) on
                    ExecutiveUserRole.MatchingID = Stage.MatchingID

        where
                Stage.MatchingID = @MatchingID
          and
                ExecutiveUserRole.UserID = @UserID
          and
                ExecutiveUserRole.RoleID = (	select RoleID
                                                from
                                                    dbo.Roles with(nolock)
                                                where
                                                        RoleCode =  3 )--executive

-- Правильный порядок для вывода в интерфейс
--order by 
--	StageType.StageTypeCode desc 
--	,Stage.IterationNumber desc



GO
/****** Object:  UserDefinedFunction [napp].[get_Tutors_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 28.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Tutors_ByMatching]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        select
            Tutor.TutorID
             ,Tutor.[Name] 				as TutorName
             ,Tutor.Surname				as TutorSurname
             ,Tutor.Patronimic			as TutorPatronimic
             ,Tutor.NameAbbreviation 	as TutorNameAbbreviation

             ,Project.ProjectID
             --,iif (Project.IsDefault = 1, 'Записаться к преподавателю' ,Project.ProjectName) as ProjectName
             ,Project.ProjectName	as ProjectName

        from
            dbo.Projects Project with (nolock)

                join dbo_v.Tutors Tutor on
                    Tutor.TutorID = Project.TutorID

        where
                Tutor.MatchingID = @MatchingID
          and
                Project.IsDefault = 1



GO
/****** Object:  UserDefinedFunction [napp].[get_FinishedMatchings]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 28.04.2020
-- Update date: 
-- Description:	
-- =============================================
create FUNCTION [napp].[get_FinishedMatchings]
()
    RETURNS  TABLE
        as
        return
        select
            Matching.MatchingID
             ,Matching.MatchingName

        from
            dbo.Matching Matching with (nolock)

                cross apply
            (
                select
                    *
                from
                    napp.get_CurrentStage_ByMatching(Matching.MatchingID)
            ) as CurrentStage

        where
                CurrentStage.StageTypeCode = 6


GO
/****** Object:  UserDefinedFunction [napp].[get_AllocatedProject_ByStudent]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 28.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_AllocatedProject_ByStudent]
(
    @StudentID int
)
    RETURNS  TABLE
        as
        return
        select
            Allocation.StudentID

             ,Project.TutorID
             ,Project.TutorName
             ,Project.TutorSurname
             ,Project.TutorPatronimic
             ,Project.TutorNameAbbreviation

             ,Project.ProjectID
             ,Project.ProjectName


        from
            dbo_v.Allocation as Allocation with(nolock)

                left join dbo_v.Projects as Project with(nolock)  on
                    Project.ProjectID = Allocation.ProjectID

        where
                StudentID = @StudentID
          and
                Allocation.StageTypeCode = 6


GO
/****** Object:  UserDefinedFunction [napp_in].[get_ProjectsPopularity]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 18.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp_in].[get_ProjectsPopularity]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        with Projects
                 as
                 (
                     select
                         Project.ProjectID
                          ,Project.TutorID
                          ,count(Preference.PreferenceID) as PreferenceCount
                          --,count (Preference.PreferenceID) over (partition by Project.TutorID ) 
                     from
                         dbo.Projects Project with (nolock)

                             left join dbo.StudentsPreferences Preference with (nolock) on
                                 Preference.ProjectID = Project.ProjectID

                     where
                             Project.MatchingID = @MatchingID
                       and
                             coalesce(Project.ProjectQuotaQty, -1) != 0

                     group by
                         Project.ProjectID
                            ,Project.TutorID
                            ,Project.ProjectQuotaQty
                 )
        select --top 5
            Project.ProjectID
             ,Project.TutorID
             ,Project.PreferenceCount as PreferenceCount_ByProject
             ,sum(Project.PreferenceCount) over (partition by Project.TutorID) as PreferenceCount_ByTutor
        from
            Projects as Project
--order by 
--	sum(Project.PreferenceCount) over (partition by TutorID) 
--	,Project.PreferenceCount



GO
/****** Object:  UserDefinedFunction [napp].[get_StudentBasicInfo]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 30.11.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StudentBasicInfo]
(
    @StudentID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Student.[StudentID]
             ,Student.[Info]
             ,Student.[Info2]


        FROM
            [dbo].[Students] Student with (nolock)


        where
            @StudentID is not null
          and
                Student.StudentID = @StudentID




GO
/****** Object:  Table [dbo].[Technologies]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Technologies](
                                     [TechnologyID] [int] IDENTITY(1,1) NOT NULL,
                                     [TechnologyName_ru] [nvarchar](200) NOT NULL,
                                     [TechnologyCode] [int] NOT NULL,
                                     CONSTRAINT [PK_Technologies] PRIMARY KEY CLUSTERED
                                         (
                                          [TechnologyID] ASC
                                             )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_Technologies_WithSelected_ByStudent]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Technologies_WithSelected_ByStudent]
(
    @StudentID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Technology.TechnologyCode as TechnologyCode
             ,Technology.TechnologyName_ru as TechnologyName_ru
             ,iif(StudentTechnology.StudentTechnologyID is not null, 1, 0) as IsSelectedByStudent

        FROM
            dbo.Technologies Technology with (nolock)

                left join dbo.Students_Technologies StudentTechnology  with (nolock) on
                        StudentTechnology.TechnologyID = Technology.TechnologyID
                    and
                        StudentTechnology.StudentID = @StudentID

        where
            @StudentID is not null




GO
/****** Object:  Table [dbo].[WorkDirections]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[WorkDirections](
                                       [DirectionID] [int] IDENTITY(1,1) NOT NULL,
                                       [DirectionName_ru] [nvarchar](200) NOT NULL,
                                       [DirectionCode] [int] NOT NULL,
                                       CONSTRAINT [PK_Directions] PRIMARY KEY CLUSTERED
                                           (
                                            [DirectionID] ASC
                                               )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_WorkDirections_WithSelected_ByStudent]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_WorkDirections_WithSelected_ByStudent]
(
    @StudentID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            WorkDirection.DirectionCode as DirectionCode
             ,WorkDirection.DirectionName_ru as DirectionName_ru
             ,iif(StudentWorkDirection.StudentDirectionID is not null, 1, 0) as IsSelectedByStudent

        FROM
            dbo.WorkDirections WorkDirection with (nolock)

                left join dbo.Students_WorkDirections StudentWorkDirection  with (nolock) on
                        StudentWorkDirection.DirectionID = WorkDirection.DirectionID
                    and
                        StudentWorkDirection.StudentID = @StudentID

        where
            @StudentID is not null




GO
/****** Object:  UserDefinedFunction [napp].[get_StudentInfo]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 30.11.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_StudentInfo]
(
    @StudentID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Student.[StudentID]
             ,Student.[GroupID]
             ,Student.[GroupName]
             ,Student.[UserID]
             ,Student.[MatchingID]
             ,Student.[Surname]
             ,Student.[Name]
             ,Student.[Patronimic]
             ,Student.[LastVisitDate]
             ,Student.[Info]
             ,Student.[Info2]
             ,Student.[WorkDirectionsName_List]
             ,Student.[TechnologiesName_List]


        FROM
            [dbo_v].[Students] Student


        where
            @StudentID is not null
          and
                Student.StudentID = @StudentID

GO
/****** Object:  Table [dbo].[Projects_Groups]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Projects_Groups](
                                        [ProjectGroupID] [int] IDENTITY(1,1) NOT NULL,
                                        [ProjectID] [int] NOT NULL,
                                        [GroupID] [int] NOT NULL,
                                        PRIMARY KEY CLUSTERED
                                            (
                                             [ProjectGroupID] ASC
                                                )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_Projects_ByStudent]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 26.11.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Projects_ByStudent]
(
    @StudentID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Project.[TutorID]
             ,Project.TutorNameAbbreviation
             ,Project.[UserID]
             ,Project.[TutorSurname]
             ,Project.[TutorName]
             ,Project.[TutorPatronimic]


             ,Project.[ProjectID]
             ,Project.[ProjectName]
             --,iif (Project.IsDefault = 1, 'Записаться к преподавателю' ,Project.ProjectName) as ProjectName
             ,Project.[Info]

             ,Project.[TechnologiesName_List]
             ,Project.[WorkDirectionsName_List]

             ,Student.StudentID
             ,Student.GroupID

             ,cast (iif (Preference.PreferenceID is not null, 1, 0) as bit) as IsSelectedByStudent
             ,Preference.PreferenceID
             ,Preference.OrderNumber

        FROM
            [dbo_v].[Projects] Project with (nolock)

                cross apply
            (
                select
                    StudentID
                     ,GroupID
                from
                    dbo.Students Student_in with (nolock)
                where
                        Student_in.StudentID = @StudentID
            ) as Student

                join dbo.Projects_Groups ProjectGroup with (nolock) on
                        ProjectGroup.ProjectID = Project.ProjectID
                    and
                        ProjectGroup.GroupID = Student.GroupID


                left join dbo.StudentsPreferences Preference with (nolock) on
                        Preference.StudentID = Student.StudentID
                    and
                        Preference.ProjectID = Project.ProjectID




        where
            @StudentID is not null
          and
                coalesce(Project.Qty, -1) != 0
--and 
--not exists (
--				select 1 
--				from dbo_v.ActiveQuotas Quota 
--				where 
--					Quota.ProjectID = Project.ProjectID 
--					and 
--					Quota.IsCommon = 0 
--					and 
--					Quota.Qty = 0 
--					and 
--					Quota.GroupID = Student.GroupID )




GO
/****** Object:  Table [dbo].[MatchingType]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MatchingType](
                                     [MatchingTypeID] [int] IDENTITY(1,1) NOT NULL,
                                     [MatchingTypeName] [nvarchar](50) NULL,
                                     [MatchingTypeName_ru] [nvarchar](50) NULL,
                                     [MatchingTypeCode] [int] NULL,
                                     CONSTRAINT [PK_MatchingType] PRIMARY KEY CLUSTERED
                                         (
                                          [MatchingTypeID] ASC
                                             )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_UserMatchings_ByRole]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 11.02.2020
-- Update date: 14.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_UserMatchings_ByRole]
(
    @UserID int
,@RoleCode int
,@RoleName nvarchar(50)
)
    returns table
        as
        return
        select distinct
            [User].UserID

                      ,Match.MatchingID
                      ,Match.MatchingName

                      ,MatchType.MatchingTypeCode
                      ,MatchType.MatchingTypeName
                      ,MatchType.MatchingTypeName_ru

        from
            dbo.Users [User] with (nolock)

                join dbo.Users_Roles UserRole with (nolock) on
                    UserRole.UserID = [User].UserID

                join dbo.Roles [Role] with (nolock) on
                    [Role].RoleID = UserRole.RoleID

                left join dbo.Matching Match with (nolock) on
                    Match.MatchingID = UserRole.MatchingID

                left join dbo.MatchingType MatchType with (nolock) on
                    MatchType.MatchingTypeID = Match.MatchingTypeID

        where
                [User].UserID = @UserID
          and
            (
                        [Role].RoleCode = coalesce(@RoleCode, -1)
                    or
                        (
                                @RoleCode is null
                                and
                                [Role].RoleName = @RoleName
                            )
                )

;


GO
/****** Object:  UserDefinedFunction [napp].[get_UserRoles_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 11.02.2020
-- Update date: 04.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_UserRoles_ByMatching]
(
    @UserID int
,@MatchingID int
)
    returns table
        as
        return
        select distinct
            UserRole.UserID
--,UserRole.MatchingID
                      ,[Role].RoleCode
                      ,[Role].RoleName
                      ,[Role].RoleName_ru
                      ,UserRole.TutorID
                      ,UserRole.StudentID

        from
            dbo.Users_Roles UserRole with (nolock)

                join dbo.Roles [Role] with (nolock) on
                    [Role].RoleID = UserRole.RoleID

        where
                UserRole.UserID = @UserID
          and
                UserRole.MatchingID = @MatchingID
;


GO
/****** Object:  UserDefinedFunction [napp].[get_Projects_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 11.05.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Projects_ByTutor]
(
    @TutorID int
)
    RETURNS  TABLE
        as
        return
        SELECT --[TutorID]
             --,[UserID]
             -- ,[TutorSurname]
             -- ,[TutorName]
             -- ,[TutorPatronimic]
            [ProjectID]
             ,[ProjectName]
             ,[Info]
             ,[IsClosed]
             ,Qty
             , QtyDescription
             ,[AvailableGroupsName_List]
             ,[TechnologiesName_List]
             ,[WorkDirectionsName_List]
             ,IsDefault
        FROM [dbo_v].[Projects]
        where
            @TutorID is not null
          and
                TutorID = @TutorID



GO
/****** Object:  UserDefinedFunction [napp].[get_ProjectBasicInfo]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 14.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_ProjectBasicInfo]
(
    @ProjectID int
)
    RETURNS  TABLE
        as
        return
        SELECT --[TutorID]
             --,[UserID]
             -- ,[TutorSurname]
             -- ,[TutorName]
             -- ,[TutorPatronimic]
            Project.[ProjectID]
             --,iif (Project.IsDefault = 1, 'Записаться к преподавателю' ,Project.ProjectName) as ProjectName
             ,Project.ProjectName as ProjectName
             ,Project.[Info]
             ,Project.[IsClosed]

             ,Project.ProjectQuotaQty as Qty
             ,iif(	Project.ProjectQuotaQty is not null
            ,cast(Project.ProjectQuotaQty as nvarchar (50))
            ,'Не важно') as QtyDescription

        FROM
            [DiplomaMatching].dbo.Projects Project with (nolock)

            --join dbo_v.ActiveQuotas ProjectQuota on 
            --	 ProjectQuota.ProjectID = Project.ProjectID
            --	 and 
            --	 ProjectQuota.GroupID is null 
            --	 and 
            --	 ProjectQuota.IsCommon = 0 -- false

        where
            @ProjectID is not null
          and
                Project.ProjectID = @ProjectID


GO
/****** Object:  Table [dbo].[Projects_Technologies]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Projects_Technologies](
                                              [ProjectTechnologyID] [int] IDENTITY(1,1) NOT NULL,
                                              [ProjectID] [int] NOT NULL,
                                              [TechnologyID] [int] NOT NULL,
                                              CONSTRAINT [PK_ProjectsTechnologies] PRIMARY KEY CLUSTERED
                                                  (
                                                   [ProjectTechnologyID] ASC
                                                      )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_Technologies_WithSelected_ByProject]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Technologies_WithSelected_ByProject]
(
    @ProjectID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Technology.TechnologyCode as TechnologyCode
             ,Technology.TechnologyName_ru as TechnologyName_ru
             ,iif(ProjectTechnology.ProjectTechnologyID is not null, 1, 0) as IsSelectedByProject

        FROM
            dbo.Technologies Technology with (nolock)

                left join dbo.Projects_Technologies ProjectTechnology  with (nolock) on
                        ProjectTechnology.TechnologyID = Technology.TechnologyID
                    and
                        ProjectTechnology.ProjectID = @ProjectID


        where
            @ProjectID is not null



GO
/****** Object:  UserDefinedFunction [napp].[get_TutorsChoice_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 21.03.2020
-- Update date: 25.04.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_TutorsChoice_ByTutor]
(
    @TutorID int
)
    RETURNS  TABLE
        as
        return
        select
            Choice.ChoiceID

             ,Student.StudentID
             ,Student.NameAbbreviation as StudentNameAbbreviation
             ,Student.GroupName

             ,Project.TutorID

             ,Project.ProjectID
             ,Project.ProjectName
             ,Project.IsClosed	as ProjectIsClosed
             ,Project.Qty
             ,Project.QtyDescription

             ,Choice.SortOrderNumber
             ,Choice.IsInQuota
             ,Choice.IsChangeble
             ,Choice.PreferenceID
             ,Choice.IsFromPreviousIteration

             ,ChoosingTypes.TypeID
             ,ChoosingTypes.TypeCode
             ,ChoosingTypes.TypeName
             ,ChoosingTypes.TypeName_ru


        from
            dbo_v.Projects Project with (nolock)

                left join dbo.TutorsChoice Choice with (nolock) on
                        Choice.ProjectID = Project.ProjectID
                    and
                        Choice.StageID = napp_in.get_CurrentStageID_ByMatching (Project.MatchingID)

                left join dbo_v.Students Student  with (nolock) on
                    Student.StudentID = Choice.StudentID

                --join dbo_v.Projects Project with (nolock) on 
                --	Project.ProjectID = Choice.ProjectID	

                left join dbo.ChoosingTypes ChoosingTypes with (nolock) on
                    ChoosingTypes.TypeID = Choice.TypeID

        where
            --Choice.StageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID) 	
            Project.TutorID = @TutorID
--and 
--Choice.StageID = napp_in.get_CurrentStageID_ByMatching (Project.MatchingID) 	


GO
/****** Object:  Table [dbo].[Projects_WorkDirections]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Projects_WorkDirections](
                                                [ProjectDirectionID] [int] IDENTITY(1,1) NOT NULL,
                                                [ProjectID] [int] NOT NULL,
                                                [DirectionID] [int] NOT NULL,
                                                CONSTRAINT [PK_Projects_Directions] PRIMARY KEY CLUSTERED
                                                    (
                                                     [ProjectDirectionID] ASC
                                                        )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_WorkDirections_WithSelected_ByProject]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_WorkDirections_WithSelected_ByProject]
(
    @ProjectID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            WorkDirection.DirectionCode as DirectionCode
             ,WorkDirection.DirectionName_ru as DirectionName_ru
             ,iif(ProjectWorkDirection.ProjectDirectionID is not null, 1, 0) as IsSelectedByProject

        FROM
            dbo.WorkDirections WorkDirection with (nolock)

                left join dbo.Projects_WorkDirections ProjectWorkDirection  with (nolock) on
                        ProjectWorkDirection.DirectionID = WorkDirection.DirectionID
                    and
                        ProjectWorkDirection.ProjectID = @ProjectID

        where
            @ProjectID is not null



GO
/****** Object:  UserDefinedFunction [napp].[get_WorkDirections_All]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 
-- Description:	
-- =============================================
create FUNCTION [napp].[get_WorkDirections_All]
()
    RETURNS  TABLE
        as
        return
        SELECT
            WorkDirection.DirectionCode as DirectionCode
             ,WorkDirection.DirectionName_ru as DirectionName_ru

        FROM
            dbo.WorkDirections WorkDirection with (nolock)



GO
/****** Object:  UserDefinedFunction [napp].[get_Technologies_All]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Technologies_All]
(
)
    RETURNS  TABLE
        as
        return
        SELECT
            Technology.TechnologyCode as TechnologyCode
             ,Technology.TechnologyName_ru as TechnologyName_ru

        FROM
            dbo.Technologies Technology with (nolock)



GO
/****** Object:  Table [dbo].[Tutors_Groups]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Tutors_Groups](
                                      [TutorGroupID] [int] IDENTITY(1,1) NOT NULL,
                                      [TutorID] [int] NOT NULL,
                                      [GroupID] [int] NOT NULL,
                                      CONSTRAINT [PK_Tutors_Groups] PRIMARY KEY CLUSTERED
                                          (
                                           [TutorGroupID] ASC
                                              )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  UserDefinedFunction [napp].[get_Groups_WithSelected_ByProject]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 14.05.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Groups_WithSelected_ByProject]
(
    @ProjectID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            g.GroupID as GroupID
             ,g.GroupName as GroupName
             ,cast (iif(pg.GroupID is null, 0, 1) as bit) as IsSelectedByProject

        FROM
            dbo.Groups g with (nolock)

                join dbo.Tutors_Groups tg with (nolock) on
                        tg.GroupID = g.GroupID
                    and
                        tg.TutorID = (select top 1 p.TutorID from dbo.Projects p with (nolock) where p.ProjectID = @ProjectID)

                left join dbo.Projects_Groups pg with (nolock) on
                        pg.GroupID = g.GroupID
                    and
                        pg.ProjectID = @ProjectID

        where
                g.MatchingID = (select top 1
                                    p.MatchingID
                                from
                                    dbo.Projects p with (nolock)
                                where
                                        p.ProjectID = @ProjectID)




GO
/****** Object:  UserDefinedFunction [napp].[get_Groups_All_ByMatching]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Groups_All_ByMatching]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            [Group].GroupID as GroupID
             ,[Group].GroupName as GroupName

        FROM
            dbo.Groups [Group] with (nolock)

        where
                [Group].MatchingID = @MatchingID

GO
/****** Object:  View [dbo_v].[Users_FullInfo]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO







-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 12.02.2020
-- Update date: 07.03.2020
-- Description:	
-- =============================================
CREATE view [dbo_v].[Users_FullInfo]
as
select
    [User].UserID
     ,[User].Surname
     ,[User].Name
     ,[User].Patronimic
     ,UserRole.LastVisitDate
     ,UserRole.MatchingID

     ,[User].Surname
    + ' ' + iif ([User].Name is not null, substring([User].Name,1, 1) , '' ) + '.'
    + ' ' + iif ([User].Patronimic is not null, substring([User].Patronimic,1, 1) , '' ) + '.'
    as NameAbbreviation

     --,coalesce(UserRole.StudentID, UserRole.TutorID) as EntityID
     ,UserRole.StudentID
     ,UserRole.TutorID

     ,Role.RoleID
     ,Role.RoleCode
     ,Role.RoleType
     ,Role.RoleName
     ,Role.RoleName_ru

     ,[Group].GroupID
     ,[Group].GroupName


from
    dbo.Users [User] with (nolock)

        left join dbo.Users_Roles UserRole with (nolock) on
            UserRole.UserID = [User].UserID

        left join dbo.Roles Role with (nolock) on
            Role.RoleID = UserRole.RoleID

        left join dbo.Students Student on
            Student.StudentID = UserRole.StudentID

        left join dbo.Groups [Group] with (nolock) on
            [Group].GroupID = Student.GroupID








GO
/****** Object:  UserDefinedFunction [napp].[get_Groups_ByTutor]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 14.05.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_Groups_ByTutor]
(
    @TutorID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            [Group].GroupID as GroupID
             ,[Group].GroupName as GroupName

        FROM
            dbo.Groups [Group] with (nolock)

                join dbo.Tutors_Groups TutorGroup with (nolock) on
                    TutorGroup.GroupID = [Group].GroupID

        where
                TutorGroup.TutorID = @TutorID


GO
/****** Object:  UserDefinedFunction [napp].[get_CommonQuota_Requests_ByExecutive]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.01.2020
-- Update date: 14.03.2020
-- Description:	
-- =============================================
CREATE FUNCTION [napp].[get_CommonQuota_Requests_ByExecutive]
(
    @UserID int
,@MatchingID int
)
    returns table
        as
        return

        select
            Quota.CommonQuotaID as QuotaID
             ,Quota.TutorID
             ,Tutor.Name
             ,Tutor.Surname
             ,Tutor.Patronimic
             ,Tutor.NameAbbreviation
             ,Quota.Qty as RequestedQuotaQty
             ,Quota.Message
             ,napp.get_CommonQuota_ByTutor(Quota.TutorID) as CurrentQuotaQty
             ,Quota.IsNotification
             ,Quota.CreateDate
             ,Quota.UpdateDate

        from
            dbo_v.CommonQuotas Quota with (nolock)

                join dbo_v.Tutors Tutor with (nolock) on
                    Tutor.TutorID = Quota.TutorID

                join Users_Roles ExecutiveUserRole with (nolock) on
                    ExecutiveUserRole.MatchingID = Quota.MatchingID


        where
                Quota.QuotaStateName = 'requested'
          and
                ExecutiveUserRole.MatchingID = @MatchingID
          and
                ExecutiveUserRole.UserID = @UserID
          and
                ExecutiveUserRole.RoleID = (	select RoleID
                                                from
                                                    dbo.Roles with(nolock)
                                                where
                                                        RoleCode =  3 )--execuеtive


GO
/****** Object:  View [dbo_v].[AvailableStudentsPreferences]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [dbo_v].[AvailableStudentsPreferences]
as
with AvailableStudentsPreferences
         as
         (
             select
                 Preference.PreferenceID
                  ,Preference.StudentID
                  ,Preference.ProjectID
                  ,Preference.OrderNumber
                  ,Preference.IsInUse
                  ,min(Preference.OrderNumber) over (partition by Preference.StudentID) as MinOrderNumber
                  ,Student.MatchingID
             from
                 dbo.StudentsPreferences Preference with (nolock)

                     join dbo.Students Student with(nolock) on
                         Student.StudentID = Preference.StudentID
             where
                     Preference.IsAvailable = 1
               and
                     Preference.IsUsed = 0
         )
select
    Preference.PreferenceID
     ,Preference.StudentID
     ,Preference.ProjectID
     ,Preference.OrderNumber
     ,Preference.IsInUse
     --,iif(Preference.IsInUse = 1, 1, null) IsFromPreviousIteration --Если Preference была в IsInUse, значит он приехала из прошлой итерации (иначе - это новый студик в списке у препода) 
     ,Preference.MatchingID

from
    AvailableStudentsPreferences Preference

where
        Preference.OrderNumber = Preference.MinOrderNumber

GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage2_Tutors]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create FUNCTION [napp].[get_StatisticStage2_Tutors]
(
    @MatchingID int
)
    RETURNS  TABLE
        as
        return
        SELECT
            Tutor.TutorID				as TutorID
             ,Tutor.Name					as TutorName
             ,Tutor.Surname				as TutorSurname
             ,Tutor.Patronimic			as TutorPatronimic
             ,Tutor.NameAbbreviation		as TutorNameAbbreviation
             ,Tutor.IsReadyToStart		as TutorIsReadyToStart
             ,Quota.Qty					as QuotaQty
             ,Tutor.LastVisitDate		as TutorLastVisitDate
             ,count (Project.ProjectID)	as ProjectsCount

        FROM
            DiplomaMatching.dbo_v.Tutors Tutor with (nolock)


                join dbo_v.ActiveCommonQuotas Quota with (nolock) on
                    Quota.TutorID = Tutor.TutorID

                left join dbo.Projects Project with (nolock) on
                    Project.TutorID = Tutor.TutorID

        where
            @MatchingID is not null
          and
                Tutor.MatchingID = @MatchingID

        group by
            Tutor.TutorID
               ,Tutor.Name
               ,Tutor.Surname
               ,Tutor.Patronimic
               ,Tutor.NameAbbreviation
               ,Tutor.IsReadyToStart
               ,Quota.Qty
               ,Tutor.LastVisitDate

GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage2_Tutor_Projects]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create function [napp].[get_StatisticStage2_Tutor_Projects]
(
    @MatchingID int
,@TutorID int
)
    RETURNS TABLE
        as
        return
        SELECT
            ProjectID						as ProjectID
             ,ProjectName					as ProjectName
             ,TechnologiesName_List			as ProjectTechnologiesName_List
             ,WorkDirectionsName_List		as ProjectWorkDirectionsName_List
             ,Qty							as ProjectsQty
             ,AvailableGroupsName_List		as ProjectAvailableGroupsName_List
        from
            dbo_v.Projects with(nolock)
        WHERE
                Projects.MatchingID = @MatchingID
          AND
                Projects.TutorID = @TutorID
GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage3_Tutors]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create function [napp].[get_StatisticStage3_Tutors](
    @MatchingID int
)
    RETURNS TABLE
        as
        return
        SELECT
            *
        FROM
            napp.get_StatisticStage2_Tutors(@MatchingID)

GO
/****** Object:  UserDefinedFunction [napp].[get_StatisticStage3_Tutor_Projects]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create function [napp].[get_StatisticStage3_Tutor_Projects]
(
    @MatchingID int
,@TutorID int
)
    RETURNS TABLE
        as
        return
        SELECT
            *
        FROM
            napp.get_StatisticStage2_Tutor_Projects(@MatchingID,@TutorID)
GO
/****** Object:  Table [dbo].[Documents]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Documents](
                                  [DocumentID] [int] IDENTITY(1,1) NOT NULL,
                                  [StageID] [int] NOT NULL,
                                  [Path] [nvarchar](max) NOT NULL,
                                  [DocumentName] [nvarchar](100) NOT NULL,
                                  CONSTRAINT [PK_Documentes] PRIMARY KEY CLUSTERED
                                      (
                                       [DocumentID] ASC
                                          )WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [dbo].[Log]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Log](
                            [Id] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
                            [Request] [text] NULL,
                            [Endpoint] [text] NULL,
                            [RequestDate] [datetime2](7) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [dbo].[CommonQuotas] ADD  CONSTRAINT [DF_CommonQuotas_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Log] ADD  CONSTRAINT [DF_Log_Id]  DEFAULT (newid()) FOR [Id]
GO
ALTER TABLE [dbo].[Projects] ADD  CONSTRAINT [DF_Projects_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Stages] ADD  CONSTRAINT [DF_Stages_StartDate]  DEFAULT (getdate()) FOR [StartDate]
GO
ALTER TABLE [dbo].[Stages] ADD  CONSTRAINT [DF_Stages_IsCurrent]  DEFAULT ((1)) FOR [IsCurrent]
GO
ALTER TABLE [dbo].[StudentsPreferences] ADD  CONSTRAINT [DF_StudentsPreferences_IsNotToUse]  DEFAULT ((1)) FOR [IsAvailable]
GO
ALTER TABLE [dbo].[StudentsPreferences] ADD  CONSTRAINT [DF_StudentsPreferences_Type]  DEFAULT ((1)) FOR [TypeID]
GO
ALTER TABLE [dbo].[StudentsPreferences] ADD  CONSTRAINT [DF_StudentsPreferences_IsInUse]  DEFAULT ((0)) FOR [IsInUse]
GO
ALTER TABLE [dbo].[StudentsPreferences] ADD  CONSTRAINT [DF_StudentsPreferences_IsUsed]  DEFAULT ((0)) FOR [IsUsed]
GO
ALTER TABLE [dbo].[StudentsPreferences] ADD  CONSTRAINT [DF_StudentsPreferences_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[Tutors] ADD  CONSTRAINT [DF_Tutors_IsClosed]  DEFAULT ((0)) FOR [IsClosed]
GO
ALTER TABLE [dbo].[TutorsChoice] ADD  CONSTRAINT [DF_TutorsChoice_SortOrderNumber]  DEFAULT ((32767)) FOR [SortOrderNumber]
GO
ALTER TABLE [dbo].[TutorsChoice] ADD  CONSTRAINT [DF_TutorsMatching_IsChangeble]  DEFAULT ((1)) FOR [IsChangeble]
GO
ALTER TABLE [dbo].[TutorsChoice] ADD  CONSTRAINT [DF_TutorsMatching_Type]  DEFAULT ((2)) FOR [TypeID]
GO
ALTER TABLE [dbo].[TutorsChoice] ADD  CONSTRAINT [DF_TutorsChoice_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[CommonQuotas]  WITH CHECK ADD  CONSTRAINT [FK_CommonQuotas_QuotasStates] FOREIGN KEY([QuotaStateID])
    REFERENCES [dbo].[QuotasStates] ([QuotaStateID])
GO
ALTER TABLE [dbo].[CommonQuotas] CHECK CONSTRAINT [FK_CommonQuotas_QuotasStates]
GO
ALTER TABLE [dbo].[CommonQuotas]  WITH CHECK ADD  CONSTRAINT [FK_CommonQuotas_Stages] FOREIGN KEY([StageID])
    REFERENCES [dbo].[Stages] ([StageID])
GO
ALTER TABLE [dbo].[CommonQuotas] CHECK CONSTRAINT [FK_CommonQuotas_Stages]
GO
ALTER TABLE [dbo].[CommonQuotas]  WITH CHECK ADD  CONSTRAINT [FK_CommonQuotas_Tutors] FOREIGN KEY([TutorID])
    REFERENCES [dbo].[Tutors] ([TutorID])
GO
ALTER TABLE [dbo].[CommonQuotas] CHECK CONSTRAINT [FK_CommonQuotas_Tutors]
GO
ALTER TABLE [dbo].[Documents]  WITH CHECK ADD  CONSTRAINT [FK_Documents_Stages] FOREIGN KEY([StageID])
    REFERENCES [dbo].[Stages] ([StageID])
GO
ALTER TABLE [dbo].[Documents] CHECK CONSTRAINT [FK_Documents_Stages]
GO
ALTER TABLE [dbo].[Groups]  WITH CHECK ADD  CONSTRAINT [FK_Groups_Matching] FOREIGN KEY([MatchingID])
    REFERENCES [dbo].[Matching] ([MatchingID])
GO
ALTER TABLE [dbo].[Groups] CHECK CONSTRAINT [FK_Groups_Matching]
GO
ALTER TABLE [dbo].[Matching]  WITH CHECK ADD  CONSTRAINT [FK_Matching_MatchingType] FOREIGN KEY([MatchingTypeID])
    REFERENCES [dbo].[MatchingType] ([MatchingTypeID])
GO
ALTER TABLE [dbo].[Matching] CHECK CONSTRAINT [FK_Matching_MatchingType]
GO
ALTER TABLE [dbo].[Projects]  WITH CHECK ADD  CONSTRAINT [FK_Projects_Tutors] FOREIGN KEY([TutorID])
    REFERENCES [dbo].[Tutors] ([TutorID])
GO
ALTER TABLE [dbo].[Projects] CHECK CONSTRAINT [FK_Projects_Tutors]
GO
ALTER TABLE [dbo].[Projects_Groups]  WITH CHECK ADD  CONSTRAINT [FK_Projects_Groups_Groups] FOREIGN KEY([GroupID])
    REFERENCES [dbo].[Groups] ([GroupID])
GO
ALTER TABLE [dbo].[Projects_Groups] CHECK CONSTRAINT [FK_Projects_Groups_Groups]
GO
ALTER TABLE [dbo].[Projects_Groups]  WITH CHECK ADD  CONSTRAINT [FK_Projects_Groups_Projects] FOREIGN KEY([ProjectID])
    REFERENCES [dbo].[Projects] ([ProjectID])
GO
ALTER TABLE [dbo].[Projects_Groups] CHECK CONSTRAINT [FK_Projects_Groups_Projects]
GO
ALTER TABLE [dbo].[Projects_Technologies]  WITH CHECK ADD  CONSTRAINT [FK_Projects_Technologies_Projects] FOREIGN KEY([ProjectID])
    REFERENCES [dbo].[Projects] ([ProjectID])
GO
ALTER TABLE [dbo].[Projects_Technologies] CHECK CONSTRAINT [FK_Projects_Technologies_Projects]
GO
ALTER TABLE [dbo].[Projects_Technologies]  WITH CHECK ADD  CONSTRAINT [FK_Projects_Technologies_Technologies] FOREIGN KEY([TechnologyID])
    REFERENCES [dbo].[Technologies] ([TechnologyID])
GO
ALTER TABLE [dbo].[Projects_Technologies] CHECK CONSTRAINT [FK_Projects_Technologies_Technologies]
GO
ALTER TABLE [dbo].[Projects_WorkDirections]  WITH CHECK ADD  CONSTRAINT [FK_Projects_WorkDirections_Projects] FOREIGN KEY([ProjectID])
    REFERENCES [dbo].[Projects] ([ProjectID])
GO
ALTER TABLE [dbo].[Projects_WorkDirections] CHECK CONSTRAINT [FK_Projects_WorkDirections_Projects]
GO
ALTER TABLE [dbo].[Projects_WorkDirections]  WITH CHECK ADD  CONSTRAINT [FK_Projects_WorkDirections_WorkDirections] FOREIGN KEY([DirectionID])
    REFERENCES [dbo].[WorkDirections] ([DirectionID])
GO
ALTER TABLE [dbo].[Projects_WorkDirections] CHECK CONSTRAINT [FK_Projects_WorkDirections_WorkDirections]
GO
ALTER TABLE [dbo].[Stages]  WITH CHECK ADD  CONSTRAINT [FK_Stages_Matching] FOREIGN KEY([MatchingID])
    REFERENCES [dbo].[Matching] ([MatchingID])
GO
ALTER TABLE [dbo].[Stages] CHECK CONSTRAINT [FK_Stages_Matching]
GO
ALTER TABLE [dbo].[Stages]  WITH CHECK ADD  CONSTRAINT [FK_Stages_StagesTypes] FOREIGN KEY([StageTypeID])
    REFERENCES [dbo].[StagesTypes] ([StageTypeID])
GO
ALTER TABLE [dbo].[Stages] CHECK CONSTRAINT [FK_Stages_StagesTypes]
GO
ALTER TABLE [dbo].[Students]  WITH CHECK ADD  CONSTRAINT [FK_Students_Groups] FOREIGN KEY([GroupID])
    REFERENCES [dbo].[Groups] ([GroupID])
GO
ALTER TABLE [dbo].[Students] CHECK CONSTRAINT [FK_Students_Groups]
GO
ALTER TABLE [dbo].[Students_Technologies]  WITH CHECK ADD  CONSTRAINT [FK_Students_Technologies_Students] FOREIGN KEY([StudentID])
    REFERENCES [dbo].[Students] ([StudentID])
GO
ALTER TABLE [dbo].[Students_Technologies] CHECK CONSTRAINT [FK_Students_Technologies_Students]
GO
ALTER TABLE [dbo].[Students_Technologies]  WITH CHECK ADD  CONSTRAINT [FK_Students_Technologies_Technologies] FOREIGN KEY([TechnologyID])
    REFERENCES [dbo].[Technologies] ([TechnologyID])
GO
ALTER TABLE [dbo].[Students_Technologies] CHECK CONSTRAINT [FK_Students_Technologies_Technologies]
GO
ALTER TABLE [dbo].[Students_WorkDirections]  WITH CHECK ADD  CONSTRAINT [FK_Students_WorkDirections_Students] FOREIGN KEY([StudentID])
    REFERENCES [dbo].[Students] ([StudentID])
GO
ALTER TABLE [dbo].[Students_WorkDirections] CHECK CONSTRAINT [FK_Students_WorkDirections_Students]
GO
ALTER TABLE [dbo].[Students_WorkDirections]  WITH CHECK ADD  CONSTRAINT [FK_Students_WorkDirections_WorkDirections] FOREIGN KEY([DirectionID])
    REFERENCES [dbo].[WorkDirections] ([DirectionID])
GO
ALTER TABLE [dbo].[Students_WorkDirections] CHECK CONSTRAINT [FK_Students_WorkDirections_WorkDirections]
GO
ALTER TABLE [dbo].[StudentsPreferences]  WITH CHECK ADD  CONSTRAINT [FK_StudentsPreferences_ChoosingTypes] FOREIGN KEY([TypeID])
    REFERENCES [dbo].[ChoosingTypes] ([TypeID])
GO
ALTER TABLE [dbo].[StudentsPreferences] CHECK CONSTRAINT [FK_StudentsPreferences_ChoosingTypes]
GO
ALTER TABLE [dbo].[StudentsPreferences]  WITH CHECK ADD  CONSTRAINT [FK_StudentsPreferences_Projects] FOREIGN KEY([ProjectID])
    REFERENCES [dbo].[Projects] ([ProjectID])
GO
ALTER TABLE [dbo].[StudentsPreferences] CHECK CONSTRAINT [FK_StudentsPreferences_Projects]
GO
ALTER TABLE [dbo].[StudentsPreferences]  WITH CHECK ADD  CONSTRAINT [FK_StudentsPreferences_Students] FOREIGN KEY([StudentID])
    REFERENCES [dbo].[Students] ([StudentID])
GO
ALTER TABLE [dbo].[StudentsPreferences] CHECK CONSTRAINT [FK_StudentsPreferences_Students]
GO
ALTER TABLE [dbo].[Tutors_Groups]  WITH CHECK ADD  CONSTRAINT [FK_Tutors_Groups_Groups] FOREIGN KEY([GroupID])
    REFERENCES [dbo].[Groups] ([GroupID])
GO
ALTER TABLE [dbo].[Tutors_Groups] CHECK CONSTRAINT [FK_Tutors_Groups_Groups]
GO
ALTER TABLE [dbo].[Tutors_Groups]  WITH CHECK ADD  CONSTRAINT [FK_Tutors_Groups_Tutors] FOREIGN KEY([TutorID])
    REFERENCES [dbo].[Tutors] ([TutorID])
GO
ALTER TABLE [dbo].[Tutors_Groups] CHECK CONSTRAINT [FK_Tutors_Groups_Tutors]
GO
ALTER TABLE [dbo].[TutorsChoice]  WITH CHECK ADD  CONSTRAINT [FK_TutorsChoice_ChoosingTypes] FOREIGN KEY([TypeID])
    REFERENCES [dbo].[ChoosingTypes] ([TypeID])
GO
ALTER TABLE [dbo].[TutorsChoice] CHECK CONSTRAINT [FK_TutorsChoice_ChoosingTypes]
GO
ALTER TABLE [dbo].[TutorsChoice]  WITH CHECK ADD  CONSTRAINT [FK_TutorsChoice_Projects] FOREIGN KEY([ProjectID])
    REFERENCES [dbo].[Projects] ([ProjectID])
GO
ALTER TABLE [dbo].[TutorsChoice] CHECK CONSTRAINT [FK_TutorsChoice_Projects]
GO
ALTER TABLE [dbo].[TutorsChoice]  WITH CHECK ADD  CONSTRAINT [FK_TutorsChoice_Stages] FOREIGN KEY([StageID])
    REFERENCES [dbo].[Stages] ([StageID])
GO
ALTER TABLE [dbo].[TutorsChoice] CHECK CONSTRAINT [FK_TutorsChoice_Stages]
GO
ALTER TABLE [dbo].[TutorsChoice]  WITH CHECK ADD  CONSTRAINT [FK_TutorsChoice_Students] FOREIGN KEY([StudentID])
    REFERENCES [dbo].[Students] ([StudentID])
GO
ALTER TABLE [dbo].[TutorsChoice] CHECK CONSTRAINT [FK_TutorsChoice_Students]
GO
ALTER TABLE [dbo].[Users_Roles]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles_Matching] FOREIGN KEY([MatchingID])
    REFERENCES [dbo].[Matching] ([MatchingID])
GO
ALTER TABLE [dbo].[Users_Roles] CHECK CONSTRAINT [FK_Users_Roles_Matching]
GO
ALTER TABLE [dbo].[Users_Roles]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles_Roles] FOREIGN KEY([RoleID])
    REFERENCES [dbo].[Roles] ([RoleID])
GO
ALTER TABLE [dbo].[Users_Roles] CHECK CONSTRAINT [FK_Users_Roles_Roles]
GO
ALTER TABLE [dbo].[Users_Roles]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles_Students] FOREIGN KEY([StudentID])
    REFERENCES [dbo].[Students] ([StudentID])
GO
ALTER TABLE [dbo].[Users_Roles] CHECK CONSTRAINT [FK_Users_Roles_Students]
GO
ALTER TABLE [dbo].[Users_Roles]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles_Tutors] FOREIGN KEY([TutorID])
    REFERENCES [dbo].[Tutors] ([TutorID])
GO
ALTER TABLE [dbo].[Users_Roles] CHECK CONSTRAINT [FK_Users_Roles_Tutors]
GO
ALTER TABLE [dbo].[Users_Roles]  WITH CHECK ADD  CONSTRAINT [FK_Users_Roles_Users] FOREIGN KEY([UserID])
    REFERENCES [dbo].[Users] ([UserID])
GO
ALTER TABLE [dbo].[Users_Roles] CHECK CONSTRAINT [FK_Users_Roles_Users]
GO
/****** Object:  StoredProcedure [napp].[create_CommonQuota_Request]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.02.2020
-- Update date: 04.04.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[create_CommonQuota_Request]
@TutorID int
,@NewQuotaQty smallint
,@Message nvarchar (250) = null
,@ProjectQuotaDelta dbo.ProjectQuota readonly
AS
BEGIN

    declare @ErrorMessage nvarchar (max);

    if (@TutorID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

    if (@NewQuotaQty is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [NewQuotaQty] не поддерживает значение NULL', 1;

    if not exists	(
            select
                1
            from
                dbo.Tutors with (nolock)
            where
                    TutorID = @TutorID
        )
        begin
            set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20));
            throw 50002, @ErrorMessage, 1;
        end;

    if exists (	select 1
                   from
                       dbo_v.CommonQuotas  with (nolock)
                   where
                           TutorID = @TutorID
                     and
                           QuotaStateName = 'requested')
        begin
            set @ErrorMessage = 'Ошибка бизнес-логики: У преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20))
                + ' имеется необработанный запрос квоты' ;
            throw 50006, @ErrorMessage, 1;
        end;


    declare @CurrentQuotaQty  int = --(select napp.get_CommonQuota_ByTutor(@TutorID)); 
        (	select
                 Qty
             from
                 [dbo_v].[CommonQuotas] with (nolock)
             where
                     TutorID = @TutorID
               and
                     QuotaStateName = 'active')


    if (@NewQuotaQty <= @CurrentQuotaQty)
        begin
            set @ErrorMessage = 'Ошибка бизнес-логики: Значение квоты нельзя уменьшить. Действующее значение общей квоты преподавателя =  '
                + cast(@CurrentQuotaQty as nvarchar(20));
            throw 50003, @ErrorMessage, 1;
        end;

    declare @QuotaRequestedStateID int = (	select
                                                  QuotaStateID
                                              from
                                                  dbo.QuotasStates with(nolock)
                                              where
                                                      QuotaStateName = 'requested')

        ,@MatchingID int = (	select
                                    MatchingID
                                from
                                    dbo.Tutors with (nolock)
                                where
                                        TutorID = @TutorID) ;

    declare
        @CurrentStageID int
        ,@CurrentStageTypeCode int;

    select
            @CurrentStageID = StageID
         ,@CurrentStageTypeCode = StageTypeCode
    from
        napp.get_CurrentStage_ByMatching(@MatchingID)
    ;


    if (@MatchingID is null )
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: У преподавателя с [TutorID] = '
                + cast(@TutorID as nvarchar(20))
                + ' не задана привязка [MatchingID]';
            throw 50004, @ErrorMessage, 1;
        end;

    if (@CurrentStageID = -1 )
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: У распределения с [MatchingID] = '
                + cast(@MatchingID as nvarchar(20))
                + ' не найдено текущей [Stage]';
            throw 50004, @ErrorMessage, 1;
        end;

    if (@CurrentStageTypeCode = 4) -- Итерации 
        begin
            if not exists (select 1 from @ProjectQuotaDelta)
                throw 50022, 'Ошибка бизнес-логики: не задан список распределения увеличенной квоты  по проектам [ProjectQuotaDelta] для этого запроса квоты.', 1;

            declare @ErrorProjectID smallint;
            --,@ErrorMaxDelta smallint; 

            set @ErrorProjectID = (select top 1 ProjectID from @ProjectQuotaDelta where Quota is null)

            if (@ErrorProjectID is not null)
                begin
                    set @ErrorMessage = 'Ошибка бизнес-логики: В списке [ProjectQuotaDelta] для проекта с [ProjectID] = '
                        + cast(@ErrorProjectID as nvarchar(20))
                        + ' задано значение дельты NULL. Для запроса квоты это недопустимо.';
                    throw 50023, @ErrorMessage, 1;
                end;

            set @ErrorProjectID = (	select top 1
                                           Delta.ProjectID
                                       from
                                           @ProjectQuotaDelta Delta

                                               join dbo.Projects Project with (nolock) on
                                                   Project.ProjectID = Delta.ProjectID

                                       where
                                               Project.TutorID != @TutorID
            )

            if (@ErrorProjectID is not null)
                begin
                    set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] = '
                        + cast(@TutorID as nvarchar(20))
                        + ' у которого есть проект с [ProjectID] = '
                        + cast(@ErrorProjectID as nvarchar(20))
                        + '.';
                    throw 50009, @ErrorMessage, 1;
                end;

            select
                    @ErrorProjectID = SetDelta.ProjectID
                    --,@ErrorMaxDelta = MaxDelta.MaxQuotaDelta
            from
                @ProjectQuotaDelta SetDelta

                    left join dbo.Projects Project with (nolock) on
                        Project.ProjectID = SetDelta.ProjectID

                --left join [napp].[get_ProjectQuota_AvailableRequestDelta_ByTutor](@TutorID) MaxDelta on
                --	SetDelta.ProjectID = MaxDelta.ProjectID
            where
                Project.ProjectID is null
               or
                        SetDelta.Quota + coalesce(Project.ProjectQuotaQty, 0) > @NewQuotaQty
            ;

            if (@ErrorProjectID is not null)
                begin
                    set @ErrorMessage = 'Ошибка бизнес-логики: В списке [ProjectQuotaDelta] для проекта с [ProjectID] = '
                        + cast(@ErrorProjectID as nvarchar(20))
                        + ' задано значение дельты, превышающее максимально допустимое '
                        + cast(@NewQuotaQty as nvarchar(20))
                        + '.' ;

                    throw 50024, @ErrorMessage, 1;
                end;

        end ;

    --======== Выполнение =========--- 
    begin tran;
    declare @CurrentDate datetime = getdate();

    insert into dbo.CommonQuotas
    (
        TutorID
    ,Qty
    ,CreateDate
    ,QuotaStateID
    ,UpdateDate
    ,IsNotification
    ,[Message]
    ,StageID
    )
    select
        @TutorID
         ,@NewQuotaQty
         ,@CurrentDate
         ,@QuotaRequestedStateID
         ,null
         ,1 --true
         ,@Message
         ,@CurrentStageID
    ;


    update
        dbo.Projects
    set
        ProjectQuotaDelta = Delta.Quota
      ,UpdateDate = @CurrentDate
    from
        @ProjectQuotaDelta Delta
    where
            Delta.ProjectID = dbo.Projects.ProjectID
    ;


    commit tran;



    return;

END

GO
/****** Object:  StoredProcedure [napp].[create_ExecutiveChoice]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 12.04.2020
-- Update date: 28.04.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[create_ExecutiveChoice]
@UserID int
,@MatchingID int
,@ProjectID int
,@StudentID int
AS
BEGIN
    declare @ErrorMessage nvarchar (300);

    if (@UserID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [UserID] не поддерживает значение NULL', 1;

    if (@MatchingID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [MatchingID] не поддерживает значение NULL', 1;

    if (@ProjectID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [ProjectID] не поддерживает значение NULL', 1;

    if (@StudentID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [StudentID] не поддерживает значение NULL', 1;

    --======= Cуществует ли =======--
    if not exists (	select 1
                       from
                           dbo.Users_Roles with (nolock)
                       where
                               MatchingID = @MatchingID
                         and
                               UserID = @UserID
                         and
                               RoleID = (	select RoleID
                                             from
                                                 dbo.Roles with(nolock)
                                             where
                                                     RoleCode =  3
                           )
        )
        begin
            set @ErrorMessage = 'Запись не существует: Не существует пользователя с [UserID] = '
                + cast (@UserID as nvarchar(20))
                + ' который является ответсвенным в распределении [MatchingID] = '
                + cast (@MatchingID as nvarchar(20))
                + '.';
            throw 50005, @ErrorMessage, 1;
        end;

    declare
        @ErrorProjectID int
        ,@ErrorStudentID int
        ,@ErrorMatchingID int ;


    select
            @ErrorProjectID = ProjectID
         ,@ErrorMatchingID = MatchingID
    from
        dbo.Projects with (nolock)
    where
            ProjectID = @ProjectID;

    if (@ErrorProjectID is null)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует проекта с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20));
            throw 50008, @ErrorMessage, 1;
        end;
    else if ((@ErrorMatchingID is null) or (@ErrorMatchingID != @MatchingID))
        begin
            set @ErrorMessage = 'Запись не существует: Не существует проекта с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20))
                + 'на распределении с [MatchingID] = '
                + cast (@MatchingID as nvarchar(20))
                + '.';
            throw 50031, @ErrorMessage, 1;
        end;

    set @ErrorMatchingID = null;

    select
            @ErrorStudentID = StudentID
         ,@ErrorMatchingID = MatchingID
    from
        dbo.Students with (nolock)
    where
            StudentID = @StudentID;

    if (@ErrorStudentID is null)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует студента с [StudentID] = '
                + cast (@StudentID as nvarchar(20));
            throw 50029, @ErrorMessage, 1;
        end;
    else if (@ErrorMatchingID != @MatchingID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует студента с [StudentID] = '
                + cast (@StudentID as nvarchar(20))
                + 'на распределении с [MatchingID] = '
                + cast (@MatchingID as nvarchar(20))
                + '.';
            throw 50030, @ErrorMessage, 1;
        end;

    --declare @DefaultProjectID int = (
    --									select top 1
    --										ProjectID 
    --									from 
    --										dbo.Projects with (nolock)
    --									where 
    --										TutorID = @TutorID 
    --										and 
    --										IsDefault = 1
    --									)
    --if (@DefaultProjectID is null)
    --begin 
    --	set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: У преподавателя с TutorID = ' 
    --						+ cast (@TutorID as nvarchar(20))
    --						+ 'нет проекта по-умолчанию "Записаться к преподавателю".' ; 
    --	throw 50004, @ErrorMessage, 1;	
    --end; 


    --======= Считаем что все ок.  =======--
    declare
        @CurDate datetime = getdate()
        ,@EndTypeID int = (select top 1 TypeID from dbo.ChoosingTypes with (nolock) where TypeName = 'End')
        ,@CurStage_ID int = (select napp_in.get_CurrentStageID_ByMatching(@MatchingID));

    begin tran;
    insert into [dbo].[TutorsChoice]
    (
        StudentID
    ,ProjectID
    ,IsInQuota
    ,IsChangeble
    ,TypeID
    ,PreferenceID
    ,IterationNumber
    ,StageID
    ,CreateDate
    ,IsFromPreviousIteration
    )
    select
        @StudentID
         ,@ProjectID
         ,1
         ,0
         ,@EndTypeID
         ,null
         ,null
         ,@CurStage_ID
         ,@CurDate
         ,0
    ;

    commit tran;


    return;

END

GO
/****** Object:  StoredProcedure [napp].[create_Project]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 13.02.2020
-- Update date: 02.04.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[create_Project]
@TutorID int
,@ProjectName nvarchar(200) = null
,@Info nvarchar(max) = null
,@QuotaQty int = null
,@Technology_CodeList nvarchar(max) = null
,@WorkDirection_CodeList nvarchar(max) = null
,@Group_IdList nvarchar(max) = null
AS
BEGIN
    declare @ErrorMessage nvarchar (300);

    if (@TutorID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

    --======= Cуществует ли такой Tutor =======--
    if not exists (	select 1
                       from
                           dbo.Tutors t with (nolock)
                       where
                               t.TutorID = @TutorID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20));
            throw 50002, @ErrorMessage, 1;
        end;

    --======= Выясняем к какому Matching принадлежит Tutor =======--
    declare @MatchingID int = ( select top 1 t.MatchingID
                                from
                                    dbo.Tutors t with (nolock)
                                where
                                        t.TutorID = @TutorID
    )
    ;

    if (@MatchingID is null)
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: У преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20))
                + ' не задана привязка [MatchingID]';
            throw 50004, @ErrorMessage, 1;
        end;

    --======= Cуществует ли у него проект с таким названием =======--
    if exists (		select 1
                       from
                           dbo.Projects p with (nolock)
                       where
                               p.TutorID = @TutorID
                         and
                               p.ProjectName = @ProjectName)
        begin
            set @ErrorMessage = 'Ошибка бизнес-логики: У преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20))
                + ' уже имеется проект с таким названием';
            throw 50100, @ErrorMessage, 1;
        end;

    --======= проверяем все ли Groups из этого Matching =======--
    if (@Group_IdList like '%[^0-9 ,]%') --Список содержит не только цифры, пробелы и запятые
        begin
            set @ErrorMessage = 'Недопустимое значение параметра: Параметр [Group_IdList] = {'
                + @Group_IdList
                + '} содержит недопустимые символы';
            throw 50007, @ErrorMessage, 1;
        end;


    create table #Groups_in --Табличка для списка приехавших ID групп
    (
        ID int
    );

    insert into #Groups_in (ID)
    select
        cast(Group_IdList.value as int)
    from
        string_split(replace(@Group_IdList, ' ', ''), ',') Group_IdList --раздираем строку по запятой
    ;

    if not exists (	select 1 --Если в списке нет ни одной группы
                       from
                           #Groups_in)
        begin
            drop table #Groups_in;
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: В списке [Group_IdList] = {'
                    + @Group_IdList
                    + '} нет значений';
                throw 50010, @ErrorMessage, 1;
            end;
        end;


    if exists (		select 1 --Если группа из другого распределения или не провязалась с группами вообще
                       from
                           #Groups_in Groups_in

                               left join dbo.Groups [Group] with (nolock) on
                                   [Group].GroupID = Groups_in.ID
                       where
                           [Group].MatchingID is null
                          or
                               [Group].MatchingID != @MatchingID)
        begin
            drop table #Groups_in;
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: В списке  [Group_IdList] = {'
                    + @Group_IdList
                    + '} нет значений GroupID, принадлежащих распределению с [MatchingID] = '
                    + cast (@MatchingID as nvarchar(20))
                    + ', к которому принадлежит преподаватель с [TutorID] = '
                    + cast (@TutorID as nvarchar(20));
                throw 50011, @ErrorMessage, 1;
            end;
        end;


    --======= проверяем значение квоты =======--
    --if (select [napp].[check_IsAvailableQuotaQty](@TutorID, null, @QuotaQty )) = 0
    --begin 
    --	drop table #Groups_in; 
    --	begin 
    --		set @ErrorMessage = 'Ошибка бизнес-логики: Значение квоты ' 
    --							+ cast (@QuotaQty as nvarchar(20))
    --							+ ' недопустимо'; 
    --		throw 50012, @ErrorMessage, 1;	
    --	end; 
    --end; 
    if	(
            (@QuotaQty is not null)
            and
            (select napp.[get_CommonQuota_ByTutor](@TutorID)) < @QuotaQty
        )
        begin
            drop table #Groups_in;
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: Значение квоты '
                    + cast (@QuotaQty as nvarchar(20))
                    + ' недопустимо';
                throw 50012, @ErrorMessage, 1;
            end;
        end;



    --======= Считаем что все ок. Создаем проект =======--
    declare
        @CurDate datetime = getdate()
    --,@ActiveQuotaState_ID int = (select top 1 QuotaStateID from dbo.QuotasStates with (nolock) where QuotaStateName = 'active')
    --,@CurStage_ID int = (select napp_in.get_CurrentStageID_ByMatching(@MatchingID));

    begin tran;

    insert into dbo.Projects
    (
        ProjectName
    ,Info
    ,TutorID
    ,IsClosed
    ,IsDefault
    ,MatchingID
    ,ProjectQuotaQty
    )
    select
        @ProjectName
         ,@Info
         ,@TutorID
         ,0
         ,0
         ,@MatchingID
         ,@QuotaQty
    ;

    declare @ProjectID int = (	select p.ProjectID
                                  from dbo.Projects p with(nolock)
                                  where
                                          p.TutorID = @TutorID
                                    and
                                          p.ProjectName = @ProjectName
                                    and
                                          p.MatchingID = @MatchingID
    );


    insert into dbo.Projects_Groups --Вставляем провязки с группами
    (
        GroupID
    ,ProjectID
    )
    select
        g.ID
         ,@ProjectID

    from
        #Groups_in g;


    insert into dbo.Projects_WorkDirections  --Связываем с направлениями. Тут подход = не нашлось кода -> игнорируем
    (
        ProjectID
    ,DirectionID
    )
    select
        @ProjectID
         ,WorkDirection.DirectionID
    from (
             select
                 value as Code
             from
                 string_split(replace(@WorkDirection_CodeList, ' ', ''), ',') WorkDirection_CodeList
             where
                     value not like '%[^0-9]%' --только числа
         ) WorkDirection_in

             join dbo.WorkDirections WorkDirection with (nolock) on
            WorkDirection.DirectionCode = cast (WorkDirection_in.Code as int)
    ;

    insert into dbo.Projects_Technologies  --Связываем с технологиями
    (
        ProjectID
    ,TechnologyID
    )
    select
        @ProjectID
         ,Technology.TechnologyID
    from (
             select
                 value as Code
             from
                 string_split(replace(@Technology_CodeList, ' ', ''), ',') Technology_CodeList
             where
                     value not like '%[^0-9]%' --только числа
         ) Technology_in

             join dbo.Technologies Technology with (nolock) on
            Technology.TechnologyCode = cast (Technology_in.Code as int)
    ;
    commit tran;

    drop table #Groups_in;
    return;

END

GO
/****** Object:  StoredProcedure [napp].[create_StudentsPreference]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 19.03.2020
-- Description:	
--				@ChoosingTypeCode и @ChoosingTypeName взаимозаменяемы
-- =============================================
CREATE PROCEDURE [napp].[create_StudentsPreference]
@StudentID int
,@ProjectID int
,@OrderNumber smallint
,@ChoosingTypeCode int = 1 -- self
,@ChoosingTypeName nvarchar(50) = 'Self'


AS
BEGIN
    declare @ErrorMessage nvarchar (300);

    if (@StudentID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [StudentID] не поддерживает значение NULL', 1;

    if (@ProjectID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [ProjectID] не поддерживает значение NULL', 1;

    if (@OrderNumber is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [OrderNumber] не поддерживает значение NULL', 1;

    if not exists (	select 1
                       from
                           dbo.Students t with (nolock)
                       where
                               t.StudentID = @StudentID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует студента с [StudentID]  = '
                + cast (@StudentID as nvarchar(20));
            throw 50013, @ErrorMessage, 1;
        end;

    if not exists (	select 1
                       from
                           dbo.Projects t with (nolock)
                       where
                               t.ProjectID = @ProjectID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует проекта с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20));
            throw 50008, @ErrorMessage, 1;
        end;

    declare @ChoosingTypeId int;
    set @ChoosingTypeId = (	select top 1
                                   TypeID
                               from
                                   dbo.ChoosingTypes with (nolock)
                               where
                                  --iif(@ChoosingTypeCode is not null,TypeCode, TypeName) = coalesce(@ChoosingTypeCode, @ChoosingTypeName)) \
                                       TypeCode = coalesce(@ChoosingTypeCode, -1)
                                  or
                                   (
                                           @ChoosingTypeCode is null
                                           and
                                           TypeName = @ChoosingTypeName
                                       )
    )

    --Обновляем 
    insert into dbo.StudentsPreferences
    (
        StudentID
    ,ProjectID
    ,OrderNumber
    ,IsAvailable
    ,TypeID
    ,IsInUse
    ,IsUsed
    ,CreateDate
    )
    select
        @StudentID
         ,@ProjectID
         ,@OrderNumber
         ,1
         ,@ChoosingTypeId
         ,0
         ,0
         ,getdate()
    ;



    return;

END




GO
/****** Object:  StoredProcedure [napp].[del_Project]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 07.03.2020
-- Update date: 02.04.2020
-- Description:	Удаление проекта. @TutorID можно не передавать (определяется по проекту), если его неудобно доставать.
-- =============================================
CREATE PROCEDURE [napp].[del_Project]
@TutorID int = null
,@ProjectID int

AS
BEGIN
    declare @ErrorMessage nvarchar (500);

    if (@ProjectID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [ProjectID] не поддерживает значение NULL', 1;

    declare
        @MatchingID int
        ,@ProjectID_check int
        ,@TutorID_check int
        ,@IsDefault bit;

    select
            @MatchingID = Project.MatchingID
         ,@ProjectID_check = Project.ProjectID
         ,@TutorID_check = Project.TutorID
         ,@IsDefault = Project.IsDefault
    from
        dbo.Projects Project with (nolock)
    where
            Project.ProjectID = @ProjectID;

--======= Cуществует ли такой Project =======--
    if (@ProjectID_check is null)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует проекта с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20));
            throw 50008, @ErrorMessage, 1;
        end;

    --======= Это ли не проект по умолчанию =======--
    if (@IsDefault = 1)
        begin
            set @ErrorMessage = 'Ошибка бизнес-логики: Проект по-умолчанию нельзя удалить' ;

            throw 50015, @ErrorMessage, 1;
        end;


    --======= Выясняем к какому Matching принадлежит Project =======--
    if (@MatchingID is null)
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: Проект с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20))
                + ' не провязан с распределением';
            throw 50004, @ErrorMessage, 1;
        end;

    --======= Выясняем к какому Tutor принадлежит Project =======--
    if (@TutorID is null)
        begin
            if (@TutorID_check is null)
                begin
                    set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] = '
                        + cast (@TutorID as nvarchar(20));
                    throw 50002, @ErrorMessage, 1;
                end;

        end;

    else
        begin
            if
                (
                        @TutorID_check is null
                        or
                        @TutorID != @TutorID_check
                    )
                begin
                    set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] = '
                        + cast (@TutorID as nvarchar(20))
                        + 'у которого есть проект с [ProjectID] = '
                        + cast (@ProjectID as nvarchar(20));
                    throw 50009, @ErrorMessage, 1;
                end;
        end;


    --======= проверяем значение квоты =======--
    --if (select [napp_in].[check_IsAvailableDeleteProject_ByQuotaQty](@ProjectID)) = 0
    --begin 
    --	drop table #Groups_in; 
    --	begin 
    --		set @ErrorMessage = 'Ошибка бизнес-логики: квота проекта с ProjectID =' 
    --							+ cast (@ProjectID as nvarchar(20))
    --							+ 'не позволяет его  удалить'; 
    --		throw 50014, @ErrorMessage, 1;	
    --	end;  
    --end; 


    --======= Считаем что все ок. Удаляем проект и все его привязки проект =======--
    begin tran;

    delete from dbo.Projects_Groups
    where ProjectID = @ProjectID;


    delete from dbo.Projects_WorkDirections
    where ProjectID = @ProjectID;


    delete from dbo.Projects_Technologies
    where ProjectID = @ProjectID;

    delete from  dbo.Projects
    where ProjectID = @ProjectID;

    commit tran;



    return;

END



GO
/****** Object:  StoredProcedure [napp].[del_StudentsPreferences]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 07.03.2020
-- Update date: 10.03.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[del_StudentsPreferences]
@StudentID int
AS
BEGIN

    if (@StudentID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [StudentID] не поддерживает значение NULL', 1;

    begin tran;
    delete
    from
        dbo.StudentsPreferences
    where
            StudentID = @StudentID;

    commit tran;


    return;

END



GO
/****** Object:  StoredProcedure [napp].[goto_NextStage]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 15.05.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[goto_NextStage]
@MatchingID int
AS
BEGIN

    declare @ErrorMessage nvarchar (max);

    if (@MatchingID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [MatchingID] не поддерживает значение NULL', 1;

    declare
        @CurStageID int
        ,@CurIterationNumber int
        ,@CurStageTypeCode int
        ,@CurDate datetime;

    select
            @CurStageID  = CurStage.StageID
         ,@CurIterationNumber  = CurStage.IterationNumber
         ,@CurStageTypeCode = CurStage.StageTypeCode
    from
        napp.get_CurrentStage_ByMatching(@MatchingID) CurStage


    if (@CurStageID is null)
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: у распределение с [MatchingID] = '
                + cast (@MatchingID as nvarchar(20))
                + ' не задано текущего этапа (stage)';
            throw 50004, @ErrorMessage, 1;
        end;

    if (@CurStageTypeCode is null)
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: у этапа с [StageID] = '
                + cast (@CurStageID as nvarchar(20))
                + ' не задан тип';
            throw 50004, @ErrorMessage, 1;
        end;

    set @CurDate = getdate();


    if (@CurStageTypeCode = 2) -- подготовка к распределнию 
        begin
            begin tran;

            exec [napp_in].[upd_Stage_CloseAndSetNew]	@CurDate = @CurDate
                ,@CurStageID = @CurStageID
                ,@CurStageTypeCode = @CurStageTypeCode
                ,@NewIterationNumber = null
                ,@MatchingID = @MatchingID
            ;

            commit tran;
            return;
        end;

    if (@CurStageTypeCode = 3) -- сбор предпочтений студентов
        begin

            begin tran;

            --exec [napp_in].[create_StudentsPreferences_Auto] @MatchingID = @MatchingID;

            exec [napp_in].[upd_Stage_CloseAndSetNew]	@CurDate = @CurDate
                ,@CurStageID = @CurStageID
                ,@CurStageTypeCode = @CurStageTypeCode
                ,@NewIterationNumber = 1
                ,@MatchingID = @MatchingID
            ;

            exec [napp_in].[create_TutorsChoice_Auto] @MatchingID = @MatchingID;

            commit tran;

            return;
        end;

    if (@CurStageTypeCode = 4) -- итерации
        begin

            begin tran;

            begin
                exec [napp_in].[upd_StudentsPreference_IsUsed] @MatchingID = @MatchingID;

                declare @NewIterationNumber smallint = @CurIterationNumber + 1;

                exec [napp_in].[upd_Stage_CloseAndSetNew]	@CurDate = @CurDate
                    ,@CurStageID = @CurStageID
                    ,@CurStageTypeCode = @CurStageTypeCode
                    ,@NewIterationNumber = @NewIterationNumber
                    ,@MatchingID = @MatchingID
                ;

                exec [napp_in].[create_TutorsChoice_Auto] @MatchingID = @MatchingID;

            end;

            -- проверить не завершилось ли распределение
            if not exists (		select  -- больше нет студентов не в квоте в списках преподавателей, т.е. преподавателям больше нечего выбирать
                                           1
                                   from
                                       dbo.TutorsChoice Choice with (nolock)
                                   where
                                           Choice.StageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID)
                                     and
                                           Choice.IsInQuota = 0
                )
                begin -- если завершилось сразу переходим на следующий этап

                set @CurStageID = napp_in.get_CurrentStageID_ByMatching (@MatchingID);

                exec [napp_in].[upd_Stage_CloseAndSetNew]	@CurDate = @CurDate
                    ,@CurStageID = @CurStageID
                    ,@CurStageTypeCode = @CurStageTypeCode
                    ,@NewIterationNumber = null
                    ,@MatchingID = @MatchingID
                ;

                -- копируем выбор с последней итерации на 5-ый этап
                exec [napp_in].[create_TutorsChoice_Copy]	@MatchingID = @MatchingID
                    ,@PreviousStageID = @CurStageID
                ;



                end;

            commit tran;

            return;
        end;
    if (@CurStageTypeCode = 5) -- ручная корректировка
        begin

            begin tran;

            exec [napp_in].[upd_Stage_CloseAndSetNew]	@CurDate = @CurDate
                ,@CurStageID = @CurStageID
                ,@CurStageTypeCode = @CurStageTypeCode
                ,@NewIterationNumber = null
                ,@MatchingID = @MatchingID
            ;

            -- копируем выбор с 5-го этапа на 6-ой
            exec [napp_in].[create_TutorsChoice_Copy]	@MatchingID = @MatchingID
                ,@PreviousStageID = @CurStageID
            ;

            commit tran;

        end;


    return;

END



GO
/****** Object:  StoredProcedure [napp].[upd_CommonQuota_Request]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.02.2020
-- Update date: 14.05.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[upd_CommonQuota_Request]
@QuotaID int
,@RequestResult bit
AS
BEGIN

    declare @ErrorMessage nvarchar (100);

    if (@QuotaID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [QuotaID] не поддерживае значение NULL', 1;

    if (@RequestResult is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [RequestResult] не поддерживае значение NULL', 1;

    if not exists (	select 1
                       from
                           dbo.CommonQuotas with (nolock)
                       where
                               CommonQuotaID = @QuotaID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [CommonQuotaID] = '
                + cast (@QuotaID as nvarchar(20));
            throw 50101, @ErrorMessage, 1;
        end;

    --======== Выполнение =========--- 
    declare
        @TutorID int
        ,@MatchingID int;

    select
            @TutorID = t.TutorID
         ,@MatchingID = t.MatchingID
    from
        dbo.CommonQuotas q with (nolock)

            join dbo.Tutors t with (nolock) on
                t.TutorID = q.TutorID
    where
            CommonQuotaID = @QuotaID;

--TODO проверить @TutorID @MatchingID

    declare @CurrentCommonQuotaID int = (	select CommonQuotaID
                                             from
                                                 dbo_v.ActiveCommonQuotas with (nolock)
                                             where
                                                     TutorID = @TutorID)

    declare
        @UnactiveQuotaStateID int = (select QuotaStateID from dbo.QuotasStates with(nolock) where QuotaStateCode = 4)
        ,@ActiveQuotaStateID int = (select QuotaStateID from dbo.QuotasStates with(nolock) where QuotaStateCode = 1)
        ,@DeclinedQuotaStateID int = (select QuotaStateID from dbo.QuotasStates with(nolock) where QuotaStateCode = 3)
        ,@CurrentDate datetime = getdate()
        ,@CurrentStageID int
        ,@CurrentStageTypeCode int;

    select
            @CurrentStageID = StageID
         ,@CurrentStageTypeCode = StageTypeCode
    from
        napp.get_CurrentStage_ByMatching(@MatchingID)
    ;

    begin tran ;
    if (@RequestResult = 1) --принять
        begin
            update dbo.CommonQuotas --сначала меняем статус у квоты, действующие на данный момент
            set
                QuotaStateID	= @UnactiveQuotaStateID
              ,UpdateDate		= @CurrentDate
              ,IsNotification	= 0
              --,StageID		= @CurrentStageID
            where
                    CommonQuotaID = @CurrentCommonQuotaID
            ;

            update dbo.CommonQuotas --потом принимаем квоту из запроса 
            set
                QuotaStateID	= @ActiveQuotaStateID
              ,UpdateDate		= @CurrentDate
              ,IsNotification	= 1
              ,StageID		= @CurrentStageID
            where
                    CommonQuotaID = @QuotaID
            ;

            if (@CurrentStageTypeCode = 4)
                begin

                    exec [napp_in].[upd_TutorsChoise_AfterQuotaChange_Auto] @MatchingID, @TutorID ; --добавили студентов в квоту 

                    update dbo.Projects
                    set
                        ProjectQuotaQty = ProjectQuotaQty + ProjectQuotaDelta
                      ,UpdateDate = @CurrentDate
                      ,ProjectQuotaDelta = null
                    where
                            TutorID = @TutorID
                      and
                        ProjectQuotaDelta is not null
                    ;

                end

        end;
    else --отклонить
        begin
            update dbo.CommonQuotas
            set
                QuotaStateID	= @DeclinedQuotaStateID
              ,UpdateDate		= @CurrentDate
              ,IsNotification	= 1
              --,StageID		= @CurrentStageID
            where
                    CommonQuotaID = @QuotaID
            ;

            if (@CurrentStageTypeCode = 4)
                update dbo.Projects
                set
                    ProjectQuotaDelta = null
                  ,UpdateDate = @CurrentDate
                where
                        TutorID = @TutorID
                  and
                    ProjectQuotaDelta is not null
                ;

        end;

    commit tran;

    return;

END

GO
/****** Object:  StoredProcedure [napp].[upd_CommonQuota_Request_ReadNotifications]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 24.02.2020
-- Update date: 14.03.2020
-- Description:	обновляет уведомление. помечает их "просмотренными". 
--				Если выполняется для ответсвенного, то обязательны перве 2 параметра. Если для преподавателя - третий параметр. 
-- =============================================
CREATE PROCEDURE [napp].[upd_CommonQuota_Request_ReadNotifications]
@UserID int = null
,@MatchingID int = null
,@TutorID int = null
AS
BEGIN

    declare @ErrorMessage nvarchar (300);

    if (@TutorID is null) -- не для тьютора, а для ответсвенного 
        begin

            if (@UserID is null)
                throw 50001, 'Недопустимый NULL параметр: Параметр [UserID] не поддерживае значение NULL при параметре [TutorID] заданном в NULL', 1;

            if (@MatchingID is null)
                throw 50001, 'Недопустимый NULL параметр: Параметр [MatchingID] не поддерживае значение NULL при параметре [TutorID] заданном в NULL', 1;

            if not exists (	select 1
                               from
                                   dbo.Users_Roles ExecutiveUser with (nolock)

                                       join  dbo.Roles ExecutiveRole with (nolock) on
                                               ExecutiveRole.RoleCode = 3 --executive
                                           and
                                               ExecutiveRole.RoleID = ExecutiveUser.RoleID
                               where
                                       ExecutiveUser.UserID = @UserID
                                 and
                                       ExecutiveUser.MatchingID = @MatchingID)
                begin
                    set @ErrorMessage = 'Запись не существует: Не существует пользователя с  [UserID] = '
                        + cast (@UserID as nvarchar(20))
                        +' который является ответсвенным в распределении [MatchingID] = '
                        + cast (@MatchingID as nvarchar(20));
                    throw 50005, @ErrorMessage, 1;
                end;

            begin tran;

            update dbo.CommonQuotas
            set
                IsNotification = 0
            from  [napp].[get_CommonQuota_Requests_ByExecutive] (@UserID,@MatchingID) Quota
            where
                    Quota.QuotaID = dbo.CommonQuotas.CommonQuotaID
              and
                    Quota.IsNotification = 1
            ;

            commit tran;
        end -- if (@TutorID is null)
    else

        begin
            if not exists (	select 1
                               from
                                   dbo.Tutors Tutor with (nolock)
                               where
                                       Tutor.TutorID = @TutorID)
                begin
                    set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] ='
                        + cast (@TutorID as nvarchar(20));
                    throw 50002, @ErrorMessage, 1;
                end;

            begin tran;

            update dbo.CommonQuotas
            set
                IsNotification = 0
            from [napp].[get_CommonQuota_Request_Notification_ByTutor](@TutorID) Quota
            where
                    Quota.QuotaID = dbo.CommonQuotas.CommonQuotaID
            ;

            commit tran;

        end -- if (@TutorID is null) else 


    return;

END


GO
/****** Object:  StoredProcedure [napp].[upd_CurrentStage_EndPlanDate]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[upd_CurrentStage_EndPlanDate]
@MatchingID int
,@NewEndPlanDate datetime = null
AS
BEGIN
    declare @ErrorMessage nvarchar (max);

    if (@MatchingID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [MatchingID] не поддерживает значение NULL', 1;

    begin tran;

    update dbo.Stages
    set EndPlanDate = @NewEndPlanDate
    where
            MatchingID = @MatchingID
      and
            IsCurrent = 1;

    commit tran;

    return;

END



GO
/****** Object:  StoredProcedure [napp].[upd_Project]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 20.02.2020
-- Update date: 02.04.2020
-- Description:	Обновление информации про проект. @TutorID можно не передавать (определяется по проекту), если его неудобно доставать.
-- =============================================
CREATE PROCEDURE [napp].[upd_Project]
@TutorID int = null
,@ProjectID int
,@ProjectName nvarchar(200) = null
,@Info nvarchar(max) = null
,@QuotaQty int = null
,@Technology_CodeList nvarchar(max) = null
,@WorkDirection_CodeList nvarchar(max) = null
,@Group_IdList nvarchar(max) = null
AS
BEGIN
    declare
        @ErrorMessage nvarchar (500)
        ,@MatchingID int
        ,@ProjectID_Check int
        ,@TutorID_Check int;

    if (@ProjectID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [ProjectID] не поддерживает значение NULL', 1;

    select
            @ProjectID_Check = p.ProjectID
         ,@MatchingID = p.MatchingID
         ,@TutorID_Check = p.TutorID
    from
        dbo.Projects p with (nolock)
    where
            p.ProjectID = @ProjectID
    ;

--======= Cуществует ли такой Project =======--
    if (@ProjectID_Check is null)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует проекта с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20));
            throw 50008, @ErrorMessage, 1;
        end;

    --======= Выясняем к какому Matching принадлежит Project =======--
    if (@MatchingID is null)
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: Проект с [ProjectID]  = '
                + cast (@ProjectID as nvarchar(20))
                + ' не провязан с распределением';
            throw 50004, @ErrorMessage, 1;
        end;

    --======= Выясняем к какому Tutor принадлежит Project =======--
    if (@TutorID is null) and (@TutorID_Check is null)
        begin
            set @ErrorMessage = 'Внутренняя ошибка бизнес-логики: У проекта с [ProjectID] =  '
                + cast (@ProjectID as nvarchar(20))
                + ' не задано преподавателя.';
            throw 50004, @ErrorMessage, 1;
        end;

    if (@TutorID is not null) and (@TutorID <> @TutorID_Check)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20))
                + ' у которого есть проект с [ProjectID] = '
                + cast (@ProjectID as nvarchar(20))
                +'.';
            throw 50009, @ErrorMessage, 1;
        end;



    --======= Cуществует ли у него другой проект с таким новым названием этого проекта =======--
    if exists (		select 1
                       from
                           dbo.Projects p with (nolock)
                       where
                               p.TutorID = @TutorID
                         and
                               p.ProjectName = @ProjectName
                         and
                               p.ProjectID !=  @ProjectID)
        begin
            set @ErrorMessage = 'Ошибка бизнес-логики: У преподавателя с [TutorID] = '
                + cast (@TutorID as nvarchar(20))
                + ' уже имеется проект с таким названием';
            throw 50100, @ErrorMessage, 1;
        end;

    --======= проверяем все ли Groups из этого Matching =======--
    if (@Group_IdList like '%[^0-9 ,]%') --Список содержит не только цифры, пробелы и запятые
        begin
            set @ErrorMessage = 'Недопустимое значение параметра: Параметр [Group_IdList] = {'
                + @Group_IdList
                + '} содержит недопустимые символы';
            throw 50007, @ErrorMessage, 1;
        end;


    create table #Groups_in --Табличка для списка приехавших ID групп
    (
        ID int
    );

    insert into #Groups_in (ID)
    select
        cast(Group_IdList.value as int)
    from
        string_split(replace(@Group_IdList, ' ', ''), ',') Group_IdList --раздираем строку по запятой
    ;

    if not exists (	select 1 --Если в списке нет ни одной группы
                       from
                           #Groups_in)
        begin
            drop table #Groups_in;
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: В списке [Group_IdList] = {'
                    + @Group_IdList
                    + '} нет значений';
                throw 50010, @ErrorMessage, 1;
            end;
        end;


    if exists (		select 1 --Если группа из другого распределения или не провязалась с группами вообще
                       from
                           #Groups_in Groups_in

                               left join dbo.Groups [Group] with (nolock) on
                                   [Group].GroupID = Groups_in.ID
                       where
                           [Group].MatchingID is null
                          or
                               [Group].MatchingID != @MatchingID)
        begin
            drop table #Groups_in;
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: В списке  [Group_IdList] = {'
                    + @Group_IdList
                    + '} нет значений GroupID, принадлежащих распределению с [MatchingID] = '
                    + cast (@MatchingID as nvarchar(20))
                    + ', к которому принадлежит преподаватель с [TutorID] = '
                    + cast (@TutorID as nvarchar(20));
                throw 50011, @ErrorMessage, 1;
            end;
        end;


    --======= проверяем значение квоты =======--
    --if (select [napp].[check_IsAvailableQuotaQty](@TutorID, @ProjectID, @QuotaQty )) = 0
    --begin 
    --	drop table #Groups_in; 
    --	begin 
    --		set @ErrorMessage = 'Ошибка бизнес-логики: Значение квоты ' 
    --							+ cast (@QuotaQty as nvarchar(20))
    --							+ 'недопустимо'; 
    --		throw 50012, @ErrorMessage, 1;	
    --	end;  
    --end; 
    if	(
            (@QuotaQty is not null)
            and
            (select napp.[get_CommonQuota_ByTutor](@TutorID)) < @QuotaQty
        )
        begin
            drop table #Groups_in;
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: Значение квоты '
                    + cast (@QuotaQty as nvarchar(20))
                    + ' недопустимо.';
                throw 50012, @ErrorMessage, 1;
            end;
        end;

    --======= Считаем что все ок. Обновляем проект =======--
    declare @CurDate datetime = getdate();

    begin tran;

    update dbo.Projects
    set
        ProjectName = @ProjectName
      ,Info = @Info
      ,ProjectQuotaQty = @QuotaQty
      ,UpdateDate = @CurDate
      --,TutorID = @TutorID
    where ProjectID = @ProjectID
    ;

--======= Обновляем провязку групп =======--
    delete from dbo.Projects_Groups
    where ProjectID = @ProjectID;

    insert into dbo.Projects_Groups --Вставляем провязки с группами
    (
        GroupID
    ,ProjectID
    )
    select
        g.ID
         ,@ProjectID

    from
        #Groups_in g;


--======= Обновляем технологии и направления ВКР, предварительно удаляя старые провязки =======--


    delete from dbo.Projects_WorkDirections
    where ProjectID = @ProjectID;

    insert into dbo.Projects_WorkDirections  --Связываем с направлениями. Тут подход = не нашлось кода -> игнорируем
    (
        ProjectID
    ,DirectionID
    )
    select
        @ProjectID
         ,WorkDirection.DirectionID
    from (
             select
                 value as Code
             from
                 string_split(replace(@WorkDirection_CodeList, ' ', ''), ',') WorkDirection_CodeList
             where
                     value not like '%[^0-9]%' --только числа
         ) WorkDirection_in

             join dbo.WorkDirections WorkDirection with (nolock) on
            WorkDirection.DirectionCode = cast (WorkDirection_in.Code as int)
    ;

    delete from dbo.Projects_Technologies
    where ProjectID = @ProjectID;

    insert into dbo.Projects_Technologies  --Связываем с технологиями
    (
        ProjectID
    ,TechnologyID
    )
    select
        @ProjectID
         ,Technology.TechnologyID
    from (
             select
                 value as Code
             from
                 string_split(replace(@Technology_CodeList, ' ', ''), ',') Technology_CodeList
             where
                     value not like '%[^0-9]%' --только числа
         ) Technology_in

             join dbo.Technologies Technology with (nolock) on
            Technology.TechnologyCode = cast (Technology_in.Code as int)
    ;

    commit tran;

    drop table #Groups_in;
    return;

END


GO
/****** Object:  StoredProcedure [napp].[upd_Project_Close]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 04.04.2020
-- Update date: 11.05.2020
-- Description:
-- =============================================
CREATE PROCEDURE [napp].[upd_Project_Close]
@TutorID int
,@ProjectID int
AS
BEGIN
    declare
        @ErrorMessage nvarchar (max);

    --------------------------------------------------------------------------
    --					Валидация данных из параметров						--
    --------------------------------------------------------------------------

    --//	NULL	//--
    begin

        if (@TutorID is null)
            throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

        if (@ProjectID is null)
            throw 50001, 'Недопустимый NULL параметр: Параметр [ProjectID] не поддерживает значение NULL', 1;

    end;

    --//	Проект принадлежит этому преподавателю	//--
    begin
        if not exists (		select
                                   1
                               from
                                   dbo.Projects with (nolock)
                               where
                                       ProjectID = @ProjectID
                                 and
                                       TutorID = @TutorID
            )
            begin
                set @ErrorMessage = 'Запись не существует:Не существует преподавателя с [TutorID] = '
                    + cast (@TutorID as nvarchar(20))
                    + ' у которого есть проект с [ProjectID] = '
                    + cast (@ProjectID as nvarchar(20))
                    +'.'
                ;
                throw 50009, @ErrorMessage, 1;
            end ;
    end;



    --------------------------------------------------------------------------
    --						Заполнение переменных							--
    --------------------------------------------------------------------------
    declare
        @MatchingID int = (select MatchingID from dbo.Tutors with (nolock) where TutorID = @TutorID)
        ,@CurrentDate datetime = getdate()
    ;

    --------------------------------------------------------------------------
    --								Выполнение								--
    --------------------------------------------------------------------------
    begin tran;

    --//	1	//--
    update dbo.Projects
    set
        IsClosed = 1
      ,CloseDate = @CurrentDate
      ,CloseStage = napp_in.get_CurrentStageID_ByMatching(@MatchingID)

    where
            ProjectID = @ProjectID;

--//	2	//--
    update dbo.StudentsPreferences
    set
        IsAvailable = 0
    where
            ProjectID = @ProjectID
      and
            IsUsed = 0
      and
            IsInUse = 0;

    commit tran;


    return;

END




GO
/****** Object:  StoredProcedure [napp].[upd_ProjectQuota_ForStage3]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 05.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[upd_ProjectQuota_ForStage3]
@TutorID int
,@ProjectID int
,@NewQuotaQty smallint
AS
BEGIN
    declare
        @ErrorMessage nvarchar (max);

    --------------------------------------------------------------------------
    --					Валидация данных из параметров						--
    --------------------------------------------------------------------------

    --//	NULL	//--
    begin

        if (@TutorID is null)
            throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

        if (@ProjectID is null)
            throw 50001, 'Недопустимый NULL параметр: Параметр [ProjectID] не поддерживает значение NULL', 1;

    end;

    --//	Проект принадлежит этому преподавателю	//--
    begin
        if not exists(	select
                              1
                          from
                              dbo.Projects with (nolock)
                          where
                                  ProjectID = @ProjectID
                            and
                                  TutorID = @TutorID
            )
            begin
                set @ErrorMessage = 'Запись не существует:Не существует преподавателя с [TutorID] = '
                    + cast (@TutorID as nvarchar(20))
                    + ' у которого есть проект с [ProjectID] = '
                    + cast (@ProjectID as nvarchar(20))
                    +'.'
                ;
                throw 50009, @ErrorMessage, 1;
            end ;
    end;

    --//	Новая квота корректна	//--
    begin
        declare @CurrentQuotaQty  int = (	select
                                                 Qty
                                             from
                                                 [dbo_v].[CommonQuotas] with (nolock)
                                             where
                                                     TutorID = @TutorID
                                               and
                                                     QuotaStateName = 'active') ;

        if (
                @NewQuotaQty is not null
                and
                (
                            @NewQuotaQty = 0
                        or
                            @NewQuotaQty > @CurrentQuotaQty
                    )
            )
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: Значение квоты по проекту =  '
                    + cast(@NewQuotaQty as nvarchar(20))
                    + ' недопустимо, поскольку превышает значение общей квоты проподавателя = '
                    + cast(@CurrentQuotaQty as nvarchar(20))
                    + '.' ;

                throw 50027, @ErrorMessage, 1;
            end;
    end;

    --TODO: проверка, что этап действительно 3ий? 

    --------------------------------------------------------------------------
    --						Заполнение переменных							--
    --------------------------------------------------------------------------
    declare
        @MatchingID int = (select MatchingID from dbo.Tutors with (nolock) where TutorID = @TutorID)
        ,@CurrentDate datetime = getdate()
    ;

    --------------------------------------------------------------------------
    --								Выполнение								--
    --------------------------------------------------------------------------
    begin tran;

    update dbo.Projects
    set
        ProjectQuotaQty = @NewQuotaQty
      ,UpdateDate = @CurrentDate
    where
            dbo.Projects.ProjectID = @ProjectID
      and
            dbo.Projects.TutorID = @TutorID;

    commit tran;


    return;

END




GO
/****** Object:  StoredProcedure [napp].[upd_ProjectsQuota_ForStage4]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 04.04.2020
-- Update date: 
-- Description:	можно передавать только измененные проекты 
-- =============================================
CREATE PROCEDURE [napp].[upd_ProjectsQuota_ForStage4]
@TutorID int = null
,@ProjectQuotaDelta dbo.ProjectQuota readonly
AS
BEGIN
    declare
        @ErrorMessage nvarchar (max)
        ,@ErrorProjectID int
        ,@ErrorDelta int;

    --------------------------------------------------------------------------
    --					Валидация данных из параметров						--
    --------------------------------------------------------------------------

    --//	NULL	//--
    begin

        if (@TutorID is null)
            throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

        if not exists (select 1 from @ProjectQuotaDelta)
            throw 50022, 'Ошибка бизнес-логики: не задан список распределения увеличенной квоты по проектам. На этапе 4 он является обязательным.', 1;

    end;

    --//	Все проекты принадлежат этом преподавателю	//--
    begin
        set @ErrorProjectID = 	(	select top 1
                                          pqd.ProjectID
                                      from
                                          @ProjectQuotaDelta pqd
                                              left join dbo.Projects p with (nolock) on
                                                      p.ProjectID = pqd.ProjectID
                                                  and
                                                      p.TutorID = @TutorID
                                      where
                                          p.ProjectID is null
        ) ;
        if (@ErrorProjectID is not null)
            begin
                set @ErrorMessage = 'Запись не существует: У преподавателя с [TutorID] = '
                    + cast (@TutorID as nvarchar(20))
                    + ' не существует проекта с [ProjectID] = '
                    + cast (@ErrorProjectID as nvarchar(20))
                    +'.'
                ;
                throw 50025, @ErrorMessage, 1;
            end ;
    end;

    --//	Все дельты квот по проектам корректны:							//--
    --//	не NULL и не превышают общую в сумме с текущей квотой проекта	//--
    begin
        declare @CurrentQuotaQty  int = (	select
                                                 Qty
                                             from
                                                 [dbo_v].[CommonQuotas] with (nolock)
                                             where
                                                     TutorID = @TutorID
                                               and
                                                     QuotaStateName = 'active') ;

        select top 1
                @ErrorProjectID = pqd.ProjectID
                   ,@ErrorDelta = pqd.Quota
        from
            @ProjectQuotaDelta pqd

                join dbo.Projects p with (nolock) on
                        p.ProjectID = pqd.ProjectID
                    and
                        p.TutorID = @TutorID
        where
            pqd.Quota  is null
           or
                pqd.Quota <= 0
           or
                    p.ProjectQuotaQty +  pqd.Quota > @CurrentQuotaQty
        ;

        if (@ErrorProjectID is not null)
            begin
                set @ErrorMessage = 'Ошибка бизнес-логики: В списке [ProjectQuotaDelta] для проекта с [ProjectID] = '
                    + cast(@ErrorProjectID as nvarchar(20))
                    + ' задано значение дельты '
                    + iif (@ErrorDelta is null, '[null]', cast(@ErrorDelta as nvarchar(20)))
                    + iif (@ErrorDelta is null,' . Это недопустимо.', ', что в сумме с текущей квотой проекта превышает общую квоту преподавателя') ;
                throw 50026, @ErrorMessage, 1;
            end;
    end;

    --TODO: проверка, что этап действительно 4ый? 

    --------------------------------------------------------------------------
    --						Заполнение переменных							--
    --------------------------------------------------------------------------
    declare
        @MatchingID int = (select MatchingID from dbo.Tutors with (nolock) where TutorID = @TutorID)
        ,@CurrentDate datetime = getdate()
    ;

    --------------------------------------------------------------------------
    --								Выполнение								--
    --------------------------------------------------------------------------
    begin tran;

    --//	1	//--
    update dbo.Projects
    set
        ProjectQuotaDelta = Delta.Quota
      ,UpdateDate = @CurrentDate
    from
        @ProjectQuotaDelta Delta
    where
            Delta.ProjectID = dbo.Projects.ProjectID
      and
            dbo.Projects.TutorID = @TutorID;

--//	2	//--
    exec [napp_in].[upd_TutorsChoise_AfterQuotaChange_Auto] @MatchingID, @TutorID ;

    --//	3	//--
    update dbo.Projects
    set
        ProjectQuotaQty = ProjectQuotaQty + ProjectQuotaDelta
      ,UpdateDate = @CurrentDate
      ,ProjectQuotaDelta = null
    where
            TutorID = @TutorID
      and
        ProjectQuotaDelta is not null
    ;

    commit tran;


    return;

END



GO
/****** Object:  StoredProcedure [napp].[upd_Student_Info]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 06.03.2020
-- Update date: 18.12.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[upd_Student_Info]
@StudentID int
,@Info nvarchar(max) = null
,@Info2 nvarchar(250) = null
,@Technology_CodeList nvarchar(max) = null
,@WorkDirection_CodeList nvarchar(max) = null

AS
BEGIN
    declare @ErrorMessage nvarchar (300);

    if (@StudentID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [StudentID] не поддерживает значение NULL', 1;

    if not exists (	select 1
                       from
                           dbo.Students t with (nolock)
                       where
                               t.StudentID = @StudentID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [StudentID]  = '
                + cast (@StudentID as nvarchar(20));
            throw 50013, @ErrorMessage, 1;
        end;

    begin tran;

    --Обновляем 
    update dbo.Students
    set
        Info = @Info
      ,Info2 = @Info2
    where
            StudentID = @StudentID;

--Предварительно удаляем старые провязки 
    delete
    from dbo.Students_Technologies
    where StudentID = @StudentID;

    delete
    from dbo.Students_WorkDirections
    where StudentID = @StudentID;


    insert into dbo.Students_WorkDirections  --Связываем с направлениями. Тут подход = не нашлось кода -> игнорируем
    (
        StudentID
    ,DirectionID
    )
    select
        @StudentID
         ,WorkDirection.DirectionID
    from (
             select
                 value as Code
             from
                 string_split(replace(@WorkDirection_CodeList, ' ', ''), ',') WorkDirection_CodeList
             where
                     value not like '%[^0-9]%' --только числа
         ) WorkDirection_in

             join dbo.WorkDirections WorkDirection with (nolock) on
            WorkDirection.DirectionCode = cast (WorkDirection_in.Code as int)
    ;

    insert into dbo.Students_Technologies  --Связываем с технологиями
    (
        StudentID
    ,TechnologyID
    )
    select
        @StudentID
         ,Technology.TechnologyID
    from (
             select
                 value as Code
             from
                 string_split(replace(@Technology_CodeList, ' ', ''), ',') Technology_CodeList
             where
                     value not like '%[^0-9]%' --только числа
         ) Technology_in

             join dbo.Technologies Technology with (nolock) on
            Technology.TechnologyCode = cast (Technology_in.Code as int)
    ;

    commit tran;

    return;

END


GO
/****** Object:  StoredProcedure [napp].[upd_Tutor_IsReadyToStart]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 24.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[upd_Tutor_IsReadyToStart]
@TutorID int
,@IsReady bit
AS
BEGIN

    declare @ErrorMessage nvarchar (300);

    if (@TutorID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

    if (@IsReady is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [IsReady] не поддерживает значение NULL', 1;

    if not exists (	select 1
                       from
                           dbo.Tutors Tutor with (nolock)
                       where
                               Tutor.TutorID = @TutorID)
        begin
            set @ErrorMessage = 'Запись не существует: Не существует преподавателя с [TutorID] ='
                + cast (@TutorID as nvarchar(20));
            throw 50002, @ErrorMessage, 1;
        end;

    begin tran;

    update dbo.Tutors
    set
        IsReadyToStart = @IsReady
    where
            TutorID = @TutorID
    ;

    commit tran;

    return;

END

GO
/****** Object:  StoredProcedure [napp].[upd_TutorsChoice]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.03.2020
-- Update date: 11.05.2020
-- Description: 
--				 Можно передавать только измененные TutorChoice
-- =============================================
CREATE PROCEDURE [napp].[upd_TutorsChoice]
@Choice_List dbo.TutorsChoice_1 readonly
,@TutorID int

AS
BEGIN
    declare @ErrorMessage nvarchar (300);

    if (@TutorID is null)
        throw 50001, 'Недопустимый NULL параметр: Параметр [TutorID] не поддерживает значение NULL', 1;

    --TODO провeрка на существование TutorID

    --TODO провeрка на пустой @Choice_List

    if exists (select 1 from @Choice_List where ChoiseID is null)
        throw 50017, 'Ошибка бизнес-логики: Недопустимый NULL параметр: Атрибут [ChoiseID] не поддерживае значение NULL. У одной или нескольких записей таблицы [Choice_List] атрибут [ChoiseID] = NULL', 1;

    declare @ErrorChoiceID int = (select top 1 ChoiseID from @Choice_List  where IsInQuota is null);

    if @ErrorChoiceID is not null
        begin
            set @ErrorMessage =  'Ошибка бизнес-логики: Недопустимый NULL параметр: Атрибут [IsInQuota] не поддерживае значение NULL. У записи с [ChoiseID] = '
                +  cast (@ErrorChoiceID as nvarchar(30))
                + ' таблицы [Choice_List] атрибут [IsInQuota] = NULL.' ;
            throw 50018, @ErrorMessage, 1;
        end;

    set @ErrorChoiceID  = (select top 1 ChoiseID from @Choice_List  where SortOrderNumber = 32767);

    if @ErrorChoiceID is not null
        begin
            set @ErrorMessage =  'Ошибка бизнес-логики: Значение [SortOrderNumber]  = 32767 не допустимо для задания пользователем. У записи с [ChoiseID] ='
                +  cast (@ErrorChoiceID as nvarchar(30))
                + ' таблицы [Choice_List] атрибут [SortOrderNumber]  = 32767.' ;
            throw 50032, @ErrorMessage, 1;
        end;

    --TODO проверка, что все @Choice_List принадлежат @TutorID

    -- Получаем MatchingID и текущую Stage
    declare
        @CurIterationNumber int
        ,@CurStageID int
        ,@MatchingID int;

    select
            @MatchingID = Tutor.MatchingID
    from
        dbo.Tutors Tutor with (nolock)
    where
            Tutor.TutorID = @TutorID;

--TODO проверка MatchingID

    select
            @CurIterationNumber = IterationNumber
         ,@CurStageID = StageID
    from
        [napp].[get_CurrentStage_ByMatching] (@MatchingID);

    --TODO проверка Stage

--Проверяем, что обновление не привысит квоты по проектма или общую квоту преподавателя 
    create table #UpdProjectQuotaFill
    (
        ProjectID int
        ,ProjectQuota_Qty smallint
        ,ProjectQuota_FillQty smallint
        ,CountChoiseListID int

    );

    insert into #UpdProjectQuotaFill
    (
        ProjectID
    ,ProjectQuota_Qty
    ,ProjectQuota_FillQty
    ,CountChoiseListID
    )
    select
        Choice.ProjectID
         ,Project.ProjectQuotaQty
         ,sum(iif(calc01.IsInQuota = 1, 1, 0))
         ,count(ChoiceList.ChoiseID)

    from
        dbo.Projects Project with (nolock)  --берем все Choice преподавателя, даже те, которые не изменились, чтобы правильно посчитать заполненную квоту 

            join dbo.TutorsChoice Choice with (nolock) on
                    Choice.ProjectID = Project.ProjectID
                and
                    Choice.StageID = @CurStageID
                and
                    Choice.IterationNumber = @CurIterationNumber

            left join @Choice_List ChoiceList on
                ChoiceList.ChoiseID = Choice.ChoiceID

            cross apply
        (
            select coalesce(ChoiceList.IsInQuota, Choice.IsInQuota) as IsInQuota
        ) as calc01

    where
            Project.TutorID = @TutorID
    group by
        Choice.ProjectID
           ,Project.ProjectQuotaQty
    ;


    if not exists (select 1 from #UpdProjectQuotaFill where  CountChoiseListID > 0)
        begin
            set @ErrorMessage =  'Ошибка бизнес-логики: предпочтения из списка [Choice_List] не принадлежат преподавателю с [TutorID] = '
                +  cast (@TutorID as nvarchar(100))  + '.';
            throw 50019, @ErrorMessage, 1;
        end;

    if exists (		select
                           1
                       from
                           #UpdProjectQuotaFill
                       where
                           ProjectQuota_Qty is not null
                         and
                               ProjectQuota_FillQty > ProjectQuota_Qty
        )
        throw 50020,  'Ошибка бизнес-логики: указанные препочтения превышают квоту по одному или нескольким проектам.', 1;


    declare
        @TutorQuota_Qty smallint = [napp].[get_CommonQuota_ByTutor](@TutorID)
        ,@TutorQuota_FillQty smallint = (select sum(ProjectQuota_FillQty) from #UpdProjectQuotaFill);


    if (@TutorQuota_FillQty > @TutorQuota_Qty)
        begin
            set @ErrorMessage =  'Ошибка бизнес-логики: указанные препочтения превышают общую квоту преподавателя с [TutorID] = '
                +  cast (@TutorID as nvarchar(30))
                + '. Общая квота = '
                + cast (@TutorQuota_Qty as nvarchar(30))
                + '. Студентов в квоте = '
                + cast (@TutorQuota_FillQty as nvarchar(30))
                + '.';
            throw 50021, @ErrorMessage, 1;
        end;

    drop table #UpdProjectQuotaFill;

--Когда все ок 
    declare @SelfChoosingTypeID int = (select TypeID from dbo.ChoosingTypes with(nolock) where TypeName = 'Self');

    begin tran;

    update
        dbo.TutorsChoice
    set
        IsInQuota = ChoiceList.IsInQuota
      ,SortOrderNumber = ChoiceList.SortOrderNumber
      ,TypeID = @SelfChoosingTypeID
      ,UpdateDate = getdate()
    from
        @Choice_List ChoiceList
    where
            ChoiceList.ChoiseID = dbo.TutorsChoice.ChoiceID
    ;

    commit tran;

    return;

END





GO
/****** Object:  StoredProcedure [napp].[upd_User_LastVisitDate]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 14.02.2020
-- Update date: 14.03.2020
-- Description:	Обновляет дату последнего посещения
-- =============================================
CREATE PROCEDURE [napp].[upd_User_LastVisitDate]
@UserID int
,@RoleCode int = null
,@RoleName nvarchar(50) = null
,@MatchingID int = null
AS
BEGIN
    declare @ErrorMessage nvarchar (max);



    declare
        @CurDateTime datetime = getdate()
        ,@RoleID int;

    update dbo.[Users]
    set
        LastVisitDate = @CurDateTime
    where
            UserID = @UserID
    ;


    if (
            @RoleCode is null
            and
            @RoleName is null
            and
            @MatchingID is not null
        )
        begin
            throw 50001, 'Недопустимый NULL параметр: Параметр [RoleCode] или [RoleName] не поддерживает значение NULL, если задан параметр [MatchingID]', 1;
        end;


    if (
            (@RoleCode is not null
                or
             @RoleName is not null)
            and
            @MatchingID is not null
        )
        begin
            set @RoleID = ( select
                                top 1 [Role].RoleID
                            from
                                dbo.Roles [Role] with(nolock)
                            where
                               --iif(@RoleCode is not null, [Role].RoleCode, [Role].RoleName) = coalesce(@RoleCode, @RoleName)
                                    [Role].RoleCode = coalesce(@RoleCode, -1)
                               or
                                (
                                        @RoleCode is null
                                        and
                                        [Role].RoleName = @RoleName
                                    )
            )
            ;
            if @RoleID is null
                begin
                    set @ErrorMessage = 'Запись не существует: Не существует роли с '
                        + iif(@RoleCode is not null, 'RoleCode', 'RoleName')
                        + ' = '
                        + cast(coalesce(@RoleCode, @RoleName) as nvarchar(200))
                        +'.';
                    --+ cast( @RoleName as nvarchar(50));
                    throw 50102, @ErrorMessage, 1;
                end;

            --TODO проверка что @MatchingID задан, если это бизнес-роль
            --TODO проверка что есть пользователь в такой роли

            begin tran;

            update dbo.Users_Roles
            set
                LastVisitDate = @CurDateTime
            where
                    UserID = @UserID
              and
                    RoleID = @RoleID
              and
                    coalesce(MatchingID, -1) = coalesce(@MatchingID, -1)
            ;
            commit tran;

        end;




    return;

END
GO
/****** Object:  StoredProcedure [napp].[upd_User_PasswordHash]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 19.02.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [napp].[upd_User_PasswordHash]
@UserID int
,@NewPasswordHash nvarchar (max)
AS
BEGIN

    --if not exists (	select 1 
    --				from dbo.Users u 
    --				where u.UserID = @UserID)
    --	return; 

    begin tran;

    update dbo.Users
    set PasswordHash = @NewPasswordHash
    where UserID = @UserID;

    commit tran;

    return;

END


GO
/****** Object:  StoredProcedure [napp_in].[create_StudentsPreferences_Auto]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 18.03.2020
-- Update date: 02.04.2020
-- Description:	Записывает студентов, у которых нет ни одного Preference, на все доступные проекты, в порядке возрастания их популярности. 
--				Как правило, делается в конце этапа 3 - сбор предпочтений студентов 
-- =============================================
CREATE PROCEDURE [napp_in].[create_StudentsPreferences_Auto]
@MatchingID int
AS
BEGIN

    declare @AutoChoosingTypeId int;
    set @AutoChoosingTypeId = (	select top 1
                                       TypeID
                                   from
                                       dbo.ChoosingTypes with (nolock)
                                   where
                                           TypeName = 'Auto'
    )
    ;


    insert into dbo.StudentsPreferences
    (
        StudentID
    ,ProjectID
    ,OrderNumber
    ,IsAvailable
    ,TypeID
    ,IsInUse
    ,IsUsed
    )
    select
        Student.StudentID
         ,Project.ProjectID
         ,ROW_NUMBER() over(partition by Student.StudentID order by PreferenceCount_ByTutor, PreferenceCount_ByProject)
         ,1
         ,@AutoChoosingTypeId
         ,0
         ,0
    from
        dbo.Students Student with (nolock)

            join dbo.Projects_Groups ProjectGroup with (nolock) on
                ProjectGroup.GroupID = Student.GroupID

            join [napp_in].[get_ProjectsPopularity](@MatchingID) Project on
                Project.ProjectID = ProjectGroup.ProjectID

    where
            Student.MatchingID = @MatchingID
      and
            Student.StudentID not in (select distinct StudentID from dbo.StudentsPreferences sp with (nolock) where MatchingID = @MatchingID)
    ;



    return;

END





GO
/****** Object:  StoredProcedure [napp_in].[create_TutorsChoice_Auto]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 21.03.2020
-- Update date: 11.05.2020
-- Description:	Выполняет вставку автоматического выбора преподавателей. Используется в начале итерации 
-- =============================================
CREATE PROCEDURE [napp_in].[create_TutorsChoice_Auto]
@MatchingID int
AS
BEGIN
    ---------------------------------------------------------------------------
    --           Автоматическое раскидывание студентов по квоте				 --
    ---------------------------------------------------------------------------

    -- Таблица Preferences, которы доступны преподавателям на текущей итерации 
    create table #CurIteration_StudentsPreferences
    (
        PreferenceID int
        ,StudentID int
        ,ProjectID int
        ,TutorID int
        ,IsInUse bit
        ,ProjectQuota_Qty smallint
        ,TutorQuota_Qty smallint
        ,IsInQuota bit
    );


--begin tran ;

    with AvailableStudentsPreferences
             as
             (
                 select
                     Preference.PreferenceID
                      ,Preference.StudentID
                      ,Preference.ProjectID
                      ,Preference.OrderNumber
                      ,Preference.IsInUse
                      ,min(Preference.OrderNumber) over (partition by Preference.StudentID) as MinOrderNumber
                 from
                     dbo.StudentsPreferences Preference with (nolock)

                         join dbo.Students Student with(nolock) on
                             Student.StudentID = Preference.StudentID
                 where
                         Preference.IsAvailable = 1
                   and
                         Preference.IsUsed = 0
                   and
                         Student.MatchingID = @MatchingID
             )
         -- Сразу проставляем В Квоте для тех предпочтений, что приехали из прошлой итерации
    insert into #CurIteration_StudentsPreferences
    (
        PreferenceID
    ,StudentID
    ,ProjectID
    ,TutorID
    ,IsInUse
    ,ProjectQuota_Qty
    ,TutorQuota_Qty
    ,IsInQuota

    )

    select
        Preference.PreferenceID
         ,Preference.StudentID
         ,Preference.ProjectID
         ,Tutor.TutorID
         ,Preference.IsInUse
         ,Project.ProjectQuotaQty
         ,TutorQuota.Qty as TutorQuota_Qty
         ,iif(Preference.IsInUse = 1, 1, null)  --Если Preference была в IsInUse, значит он приехала из прошлой итерации (иначе - это новый студик в списке у препода) 

    from
        AvailableStudentsPreferences Preference

            join dbo.Projects Project with (nolock) on
                Project.ProjectID = Preference.ProjectID

            join dbo.Tutors Tutor with(nolock) on
                Tutor.TutorID = Project.TutorID

            join dbo_v.ActiveCommonQuotas TutorQuota with(nolock) on
                TutorQuota.TutorID = Tutor.TutorID

    where
            Preference.OrderNumber = Preference.MinOrderNumber
    ;


----Проставляем В квоте
    with AvailableStudentsPreferences
        as
        (
            select
                *
                 ,sum(iif(Preference.IsInQuota = 1, 1, 0)) over (partition by Preference.ProjectID) as ProjectQuota_FillQty
                 ,sum(iif(Preference.IsInQuota = 1, 1, 0)) over (partition by Preference.TutorID) as TutorQuota_FillQty
            from
                #CurIteration_StudentsPreferences Preference
        )
       ,AvailableStudentsPreferences_ProjectQuotaConstraint -- определяем тех, ктоне пролез по квоте проекта
        as
        (
            select
                Preference.*
                 ,ProjectQuota_FreeQty
                 ,TutorQuota_FreeQty

                 , iif (
                        row_number() over  (partition by Preference.ProjectID order by Preference.PreferenceID) <= ProjectQuota_FreeQty
                , 1
                , 0
                ) as IsAvailable_ByProjectQuota

            from
                AvailableStudentsPreferences Preference

                    cross apply
                (
                    select
                            coalesce(Preference.ProjectQuota_Qty, Preference.TutorQuota_Qty) - Preference.ProjectQuota_FillQty as ProjectQuota_FreeQty
                         ,Preference.TutorQuota_Qty - Preference.TutorQuota_FillQty as TutorQuota_FreeQty
                ) as calc01

            where
                Preference.IsInQuota is null
        )
       ,AvailableStudentsPreferences_Quota -- проставляем в квоте или нет на основе квоты преподавателя. 
        as
        (
            select
                Preference.PreferenceID
                 --,row_number() over  (partition by Preference.TutorID order by Preference.IsAvailable_ByProjectQuota desc) as StudernOrder_Tutor

                 , iif (
                            Preference.IsAvailable_ByProjectQuota = 1 --Тех кто отмечен невлазящим в квоту проекта, помечаем как не в квоте без проверки квоты препода
                        and
                            row_number() over  (partition by Preference.TutorID order by Preference.IsAvailable_ByProjectQuota desc) <= TutorQuota_FreeQty
                ,1
                ,0
                ) as IsInQuota_Calc

            from
                AvailableStudentsPreferences_ProjectQuotaConstraint Preference
        )
    update
        #CurIteration_StudentsPreferences
    set
        IsInQuota = IsInQuota_Calc
    from
        AvailableStudentsPreferences_Quota p
    where
            #CurIteration_StudentsPreferences.PreferenceID = p.PreferenceID
    ;


    --------------------------------------------------------------------------
---- Складывание результата в таблицу Choise и обновление Preferences

    declare
        @CurIterationNumber int
        ,@CurStageID int
        ,@AutoChoosingTypeID int = (select TypeID from dbo.ChoosingTypes where TypeName = 'Auto');

    select
            @CurIterationNumber = IterationNumber
         ,@CurStageID = StageID
    from
        [napp].[get_CurrentStage_ByMatching] (@MatchingID);

    insert into dbo.TutorsChoice
    (
        StudentID
    ,ProjectID
    ,SortOrderNumber
    ,IsInQuota
    ,IsChangeble
    ,TypeID
    ,PreferenceID
    ,IterationNumber
    ,StageID
    ,CreateDate
    ,UpdateDate
    ,IsFromPreviousIteration
    )
    select
        Preference.StudentID
         ,Preference.ProjectID
         ,coalesce(LastChoise.SortOrderNumber, 32767)
         ,Preference.IsInQuota
         ,coalesce(LastChoise.IsChangeble, 1)
         ,coalesce(LastChoise.TypeID, @AutoChoosingTypeID)
         ,Preference.PreferenceID
         ,@CurIterationNumber
         ,@CurStageID
         ,getdate()
         ,null
         ,iif(LastChoise.ChoiceID is not null, 1, 0)

    from
        #CurIteration_StudentsPreferences Preference

            left join dbo.TutorsChoice LastChoise with (nolock) on
                    LastChoise.PreferenceID = Preference.PreferenceID
                and
                    LastChoise.IterationNumber = @CurIterationNumber - 1
                and
                    LastChoise.IsInQuota = 1
    ;

    update
        dbo.StudentsPreferences
    set
        IsInUse = 1
    from
        #CurIteration_StudentsPreferences
    where
            dbo.StudentsPreferences.PreferenceID = #CurIteration_StudentsPreferences.PreferenceID
    ;

--commit tran;

    drop table #CurIteration_StudentsPreferences;


    -----------------------------------------------------------------------------
----           Автоматическое раскидывание студентов по квоте				 --
-----------------------------------------------------------------------------

---- Таблица Preferences, которы доступны преподавателям на текущей итерации 
--create table #CurIteration_StudentsPreferences
--(
--	PreferenceID int 
--	,StudentID int
--	,ProjectID int
--	,TutorID int
--	,IsInUse bit
--	,ProjectQuota_Qty smallint
--	,TutorQuota_Qty smallint 
--	,IsInQuota bit
--);

--with AvailableStudentsPreferences
--as 
--(
--	select 
--		Preference.PreferenceID
--		,Preference.StudentID
--		,Preference.ProjectID
--		,Preference.OrderNumber
--		,Preference.IsInUse
--		,min(Preference.OrderNumber) over (partition by Preference.StudentID) as MinOrderNumber
--	from 
--		dbo.StudentsPreferences Preference with (nolock) 

--		join dbo.Students Student with(nolock) on 
--			Student.StudentID = Preference.StudentID 
--	where 
--		Preference.IsAvailable = 1
--		and 
--		Preference.IsUsed = 0
--		and 
--		Student.MatchingID = @MatchingID
--)
---- Сразу проставляем В Квоте для тех предпочтений, что приехали из прошлой итерации
--insert into #CurIteration_StudentsPreferences
--(
--	PreferenceID  
--	,StudentID 
--	,ProjectID 
--	,TutorID
--	,IsInUse 
--	,ProjectQuota_Qty 
--	,TutorQuota_Qty  
--	,IsInQuota

--) 

--select 
--	Preference.PreferenceID
--	,Preference.StudentID
--	,Preference.ProjectID
--	,Tutor.TutorID
--	,Preference.IsInUse 
--	,Project.ProjectQuotaQty 
--	,TutorQuota.Qty as TutorQuota_Qty
--	,iif(Preference.IsInUse = 1, 1, null)  --Если Preference была в IsInUse, значит он приехала из прошлой итерации (иначе - это новый студик в списке у препода) 

--from 
--	AvailableStudentsPreferences Preference

--	join dbo.Projects Project with (nolock) on 
--		Project.ProjectID = Preference.ProjectID 

--	join dbo.Tutors Tutor with(nolock) on 
--		Tutor.TutorID = Project.TutorID

--	join dbo_v.ActiveCommonQuotas TutorQuota with(nolock) on 
--		TutorQuota.TutorID = Tutor.TutorID

--where 
--	Preference.OrderNumber = Preference.MinOrderNumber
--;


----Проставляем В квоте/ Не в квоте сначала по тем проектам, где есть Квота по проекту (считаем их более приоритетными)
--with AvailableStudentsPreferences
--as 
--(
--	select 
--		*
--		,sum(iif(Preference.IsInQuota = 1, 1, 0)) over (partition by Preference.ProjectID) as ProjectQuota_FillQty
--		,sum(iif(Preference.IsInQuota = 1, 1, 0)) over (partition by Preference.TutorID) as TutorQuota_FillQty		
--	from 
--		#CurIteration_StudentsPreferences Preference
--)
--,AvailableStudentsPreferences_Quota
--as
--(
--	select 
--		Preference.* 
--		,iif (ProjectQuota_FreeQty < TutorQuota_FreeQty, ProjectQuota_FreeQty,TutorQuota_FreeQty) as ProjectQuota_AvailableQty --может быть ситуация когда общую квоту забили студики по другому проекту и не смотря на квоту заданную на текущий проект (напр. 2) к преподу по общей квоте лезет меньше студентов (напр. 1) 
--		,row_number() over  (partition by Preference.ProjectID order by Preference.PreferenceID) as StudernOrderCount
--	from
--		AvailableStudentsPreferences Preference

--		cross apply 
--		(
--			select 
--				Preference.ProjectQuota_Qty - Preference.ProjectQuota_FillQty as ProjectQuota_FreeQty
--				,Preference.TutorQuota_Qty - Preference.TutorQuota_FillQty as TutorQuota_FreeQty
--		) as calc01

--	where
--		Preference.IsInQuota is null
--		and 
--		Preference.ProjectQuota_Qty is not null 
--)
--update 
--	#CurIteration_StudentsPreferences 
--set 
--	IsInQuota = iif (StudernOrderCount <= ProjectQuota_AvailableQty, 1, 0)
--from 
--	AvailableStudentsPreferences_Quota p
--where 
--	#CurIteration_StudentsPreferences.PreferenceID = p.PreferenceID
--;


---- Теперь по оставшимся проектам (без квоты) 
--with AvailableStudentsPreferences
--as 
--(
--	select 
--		*
--		,sum(iif(Preference.IsInQuota = 1, 1, 0)) over (partition by Preference.TutorID) as TutorQuota_FillQty	--теперь нас интересует кол-во в рамках только преподавателя
--	from 
--		#CurIteration_StudentsPreferences Preference
--)
--,AvailableStudentsPreferences_Quota
--as
--(
--	select 
--		Preference.* 
--		,Preference.TutorQuota_Qty - Preference.TutorQuota_FillQty as TutorQuota_AvailableQty 
--		,row_number() over  (partition by Preference.TutorID order by Preference.PreferenceID) as StudernOrderCount
--	from
--		AvailableStudentsPreferences Preference

--	where
--		Preference.IsInQuota is null
--		and 
--		Preference.ProjectQuota_Qty is null 
--)
--update 
--	#CurIteration_StudentsPreferences 
--set 
--	IsInQuota = iif (StudernOrderCount <= TutorQuota_AvailableQty, 1, 0)
--from 
--	AvailableStudentsPreferences_Quota p
--where 
--	#CurIteration_StudentsPreferences.PreferenceID = p.PreferenceID
--;


--------------------------------------------------------------------------
---- Складывание результата в таблицу Choise и обновление Preferences

--declare 
--	@CurIterationNumber int
--	,@CurStageID int
--	,@AutoChoosingTypeID int = (select TypeID from dbo.ChoosingTypes where TypeName = 'Auto'); 

--select 
--	@CurIterationNumber = IterationNumber 
--	,@CurStageID = StageID
--from 
--	[napp].[get_CurrentStage_ByMatching] (@MatchingID);

--insert into dbo.TutorsChoice 
--(
--	StudentID
--	,ProjectID
--	,SortOrderNumber
--	,IsInQuota
--	,IsChangeble
--	,TypeID
--	,PreferenceID
--	,IterationNumber
--	,StageID
--	,CreateDate
--	,UpdateDate
--	,IsFromPreviousIteration
--)
--select 
--	Preference.StudentID
--	,Preference.ProjectID
--	,LastChoise.SortOrderNumber
--	,Preference.IsInQuota
--	,coalesce(LastChoise.IsChangeble, 1) 
--	,@AutoChoosingTypeID
--	,Preference.PreferenceID
--	,@CurIterationNumber
--	,@CurStageID
--	,getdate() 
--	,null
--	,iif(LastChoise.ChoiceID is not null, 1, 0)

--from 
--	#CurIteration_StudentsPreferences Preference

--	left join dbo.TutorsChoice LastChoise with (nolock) on 
--		LastChoise.PreferenceID = Preference.PreferenceID
--		and 
--		LastChoise.IterationNumber = @CurIterationNumber - 1
--		and 
--		LastChoise.IsInQuota = 1 
--;

--update 
--	dbo.StudentsPreferences 
--set 
--	IsInUse = 1
--from 
--	#CurIteration_StudentsPreferences 
--where 
--	dbo.StudentsPreferences.PreferenceID = #CurIteration_StudentsPreferences.PreferenceID
--;

--drop table #CurIteration_StudentsPreferences;

    return;

END









GO
/****** Object:  StoredProcedure [napp_in].[create_TutorsChoice_Copy]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [napp_in].[create_TutorsChoice_Copy]
@MatchingID int
,@PreviousStageID int

AS
BEGIN

    declare
        @CurStageID int =(select napp_in.get_CurrentStageID_ByMatching (@MatchingID))
    ;


    begin tran;
    insert into dbo.TutorsChoice
    (
        StudentID
    ,ProjectID
    ,SortOrderNumber
    ,IsInQuota
    ,IsChangeble
    ,TypeID
    ,PreferenceID
    ,IterationNumber
    ,StageID
    ,CreateDate
    ,UpdateDate
    ,IsFromPreviousIteration
    )
    select
        Choice.StudentID
         ,Choice.ProjectID
         ,Choice.SortOrderNumber
         ,Choice.IsInQuota
         ,Choice.IsChangeble
         ,Choice.TypeID
         ,Choice.PreferenceID
         ,null
         ,@CurStageID
         ,getdate()
         ,null
         ,null

    from
        dbo.TutorsChoice Choice with (nolock)
    where
            Choice.StageID = @PreviousStageID
    ;

    commit tran;

    return;

END








GO
/****** Object:  StoredProcedure [napp_in].[upd_Stage_CloseAndSetNew]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 19.03.2020
-- Update date: 04.04.2020
-- Description:	Закрывает текущую итерацию и создает следующую. 
-- =============================================
CREATE PROCEDURE [napp_in].[upd_Stage_CloseAndSetNew]
@CurDate datetime = null
,@CurStageID int
,@CurStageTypeCode int
,@NewIterationNumber int = null
,@MatchingID int
AS
BEGIN

    declare @NewStageTypeID int;

    begin tran ;

    update dbo.Stages
    set
        EndDate = @CurDate
      ,IsCurrent = 0
    where
            StageID = @CurStageID;


    if (@CurStageTypeCode = 2)
        begin
            set @NewStageTypeID = (	select top(1)
                                           StageTypeID
                                       from
                                           dbo.StagesTypes with (nolock)
                                       where
                                               StageTypeCode = 3
            )
            ;
            set @NewIterationNumber = null;
        end
    else if
        (
                (@CurStageTypeCode = 3)
                or
                ((@CurStageTypeCode = 4) and (@NewIterationNumber is not null))
            )
        begin
            set @NewStageTypeID = (	select top(1)
                                           StageTypeID
                                       from
                                           dbo.StagesTypes with (nolock)
                                       where
                                               StageTypeCode = 4
            )
            ;
            --set @NewIterationNumber = 1; 
        end
    else if ((@CurStageTypeCode = 4) and (@NewIterationNumber is null))
        begin
            set @NewStageTypeID = (	select top(1)
                                           StageTypeID
                                       from
                                           dbo.StagesTypes with (nolock)
                                       where
                                               StageTypeCode = 5
            )
            ;
            --set @NewIterationNumber = 1; 
        end;
    if (@CurStageTypeCode = 5)
        begin
            set @NewStageTypeID = (	select top(1)
                                           StageTypeID
                                       from
                                           dbo.StagesTypes with (nolock)
                                       where
                                               StageTypeCode = 6
            )
            ;
            set @NewIterationNumber = null;
        end


    insert into dbo.Stages
    (
        StageTypeID
    ,StageName
    ,IterationNumber
    ,StartDate
    ,EndPlanDate
    ,IsCurrent
    ,MatchingID
    )
    select
        @NewStageTypeID
         ,null
         ,@NewIterationNumber
         ,@CurDate
         ,null
         ,1
         ,@MatchingID
    ;

    commit tran ;

    return;

END












GO
/****** Object:  StoredProcedure [napp_in].[upd_StudentsPreference_IsUsed]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO





-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 22.03.2020
-- Update date: 04.04.2020
-- Description:	
-- =============================================
CREATE PROCEDURE [napp_in].[upd_StudentsPreference_IsUsed]
@MatchingID int
AS
BEGIN


    update
        dbo.StudentsPreferences
    set
        IsInUse = 0
      ,IsUsed = 1

    from
        dbo_v.AvailableStudentsPreferences  Preference with (nolock)

            join dbo.TutorsChoice Choice with (nolock) on
                    Choice.PreferenceID = Preference.PreferenceID
                and
                    Choice.StageID = (select napp_in.get_CurrentStageID_ByMatching (@MatchingID) )

    where
            Preference.MatchingID = @MatchingID
      and
            Choice.IsInQuota = 0
      and
            Preference.PreferenceID = dbo.StudentsPreferences.PreferenceID;


    return;

END






GO
/****** Object:  StoredProcedure [napp_in].[upd_TutorsChoise_AfterQuotaChange_Auto]    Script Date: 31.10.2021 15:09:48 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO






-- =============================================
-- Author:		Antyukhova Ekaterina
-- Create date: 04.04.2020
-- Update date: 
-- Description:	
-- =============================================
CREATE PROCEDURE [napp_in].[upd_TutorsChoise_AfterQuotaChange_Auto]
@MatchingID int
,@TutorID int
AS
BEGIN
    ---------------------------------------------------------------------------
    --           Автоматическое раскидывание студентов по квоте				 --
    --           после изменение квоты по проектам и/или общей				 --
    ---------------------------------------------------------------------------
    create table #UpdInQuota_Choice
    (
        ChoiceID int
        ,PreferenceID int
    );

    begin tran;

    declare
        @AutoTypeID int = (select TypeID from dbo.ChoosingTypes with (nolock) where TypeName = 'Auto')
        ,@CurDate datetime = getdate();

    with Choise_ByProject
        as
        (
            select
                Choice.*
                 ,Project.ProjectQuotaQty
                 ,Project.ProjectQuotaDelta
                 ,Tutor.Qty  as CommonQuotaQty
                 --, 2 as CommonQuotaQty
                 , sum (iif (Choice.IsInQuota = 1 , 1, 0)) over (partition by Tutor.TutorID) as CommonQuotaFill --считаем сколько из общей квоты заполнено 
                 , row_number() over (partition by Project.ProjectID, Choice.IsInQuota  order by Choice.SortOrderNumber) as OutQuotaProject_RN --нумеруем в пределах проекта 
                 --, Tutor.IsToUpdate
                 , Tutor.TutorID

            from
                dbo.TutorsChoice Choice with (nolock)

                    join dbo.Projects Project with (nolock) on
                        Project.ProjectID = Choice.ProjectID

                    join [dbo_v].[ActiveCommonQuotas] Tutor with (nolock) on
                        Tutor.TutorID = Project.TutorID

            where  --выбираем за текущую итерацию 
                    Choice.StageID = (select napp_in.get_CurrentStageID_ByMatching (@MatchingID) )
              and
                    Tutor.TutorID = @TutorID

        )
       , Choise_ByTutor
        as
        (
            select
                PreferenceID
                 ,ChoiceID
                 ,CommonQuotaQty - CommonQuotaFill as CommonQuotaFree  -- сколько вообще можно докинуть студентов в квоту 
                 ,row_number() over (partition by TutorID  order by SortOrderNumber) as OutQuotaTutor_RN -- нумерум уже в пределах преподавателя 
            from
                Choise_ByProject
            where
                    OutQuotaProject_RN <= ProjectQuotaDelta -- выкидываем тех, кто не влез в дельту квоты по проетку (из тех кто не был в квоте)
              and
                    IsInQuota = 0 -- из тех кто не в квоте 
              and
                ProjectQuotaDelta is not null -- для тех , проектов, где вообще надо добавлять студентов 
        )
    insert into #UpdInQuota_Choice
    (
        ChoiceID		--в итоге у нас остаются только те кто был не в квоте и должны попать в нее теперь 
    ,PreferenceID
    )
    select
        ChoiceID
         ,PreferenceID
    from
        Choise_ByTutor
    where
            OutQuotaTutor_RN <= CommonQuotaFree --выкидываем тех, кто не влез в общую квоту (в разницу между тем сколько уже взято в квоту и значениме квоты), 
--помня о том, что мы смотрим только на тех, кто не был в квоте до этого 
    ;


    update dbo.TutorsChoice
    set
        IsInQuota = 1
      ,TypeID = @AutoTypeID
      ,UpdateDate = @CurDate
    from
        #UpdInQuota_Choice UpdChoice
    where
            UpdChoice.ChoiceID =  dbo.TutorsChoice.ChoiceID
    ;


    commit tran;

    drop table #UpdInQuota_Choice;

    return;

END







