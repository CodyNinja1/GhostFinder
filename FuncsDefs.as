const uint OffsetReplayInfoChallengeId = 0x38;
const uint OffsetGhostChallengeId = 0x120;

CGameCtnChallenge@ MapToChallenge(const string &in map)
{
    return cast<CGameCtnChallenge>(Fids::Preload(Fids::GetUser("Maps/" + MapToPath(map))));
}

string MapToPath(const string &in map)
{
    string MapPath = "";
    int MapNumber = Text::ParseInt(map);

    int Color;
    
    if (MapNumber <= 40)
    {
        Color = 1;
    }
    else if (MapNumber <= 80)
    {
        Color = 2;
    }
    else if (MapNumber <= 120)
    {
        Color = 3;
    }
    else if (MapNumber <= 160)
    {
        Color = 4;
    }
    else if (MapNumber <= 200)
    {
        Color = 5;
    }

    string ColorName = "";

    switch (Color)
    {
        case 1:
            ColorName = "White";
            break;
        case 2:
            ColorName = "Green";
            break;
        case 3:
            ColorName = "Blue";
            break;
        case 4:
            ColorName = "Red";
            break;
        case 5:
            ColorName = "Black";
            break;
    }

    string Flag = "0" + Color + "_" + ColorName;

    string Environment = "";
    
    int EnviNumber = MapNumber % 40;

    if (EnviNumber >= 1 && EnviNumber <= 10)
    {
        EnviNumber = 1;
    }
    else if (EnviNumber >= 11 && EnviNumber <= 20)
    {
        EnviNumber = 2;
    }
    else if (EnviNumber >= 21 && EnviNumber <= 30)
    {
        EnviNumber = 3;
    }
    else if ((EnviNumber >= 31 && EnviNumber <= 39) || EnviNumber == 0)
    {
        EnviNumber = 4;
    }

    switch (EnviNumber)
    {
        case 1:
            Environment = "Canyon";
            break;
        case 2:
            Environment = "Valley";
            break;
        case 3:
            Environment = "Lagoon";
            break;
        case 4:
            Environment = "Stadium";
            break;
    }

    Environment = "0" + EnviNumber + "_" + Environment;

    MapPath = "Campaigns/" + Flag + "/" + Environment + "/" + map + ".Map.Gbx";

    return MapPath;
}

void PlayMap(const string &in MapLoc)
{
    cast<CGameManiaPlanet>(GetApp()).ManiaTitleFlowScriptAPI.PlayMap(MapLoc, "TrackMania/TMC_CampaignSolo.Script.txt", "");
}

string GetSoloKind(const string &in GhostKind)
{
    if (GhostKind.StartsWith("Solo")) return "Solo";
    return "Double Driver";
}

void RenderMatch(Match Match)
{
    UI::Text(tostring(Match));
    if (UI::IsItemHovered())
    {
        UI::BeginTooltip();
        UI::Text("UID " + Match.MapUID + " matched with map #" + Match.MapNum + "'s UID\nThis ghost was driven in " + Match.GhostSolo);
        if (!IsConvertingReplay) UI::Text("Right-click to edit this ghost.");
        else UI::Text("Please finish converting the currently active replay.");
        UI::EndTooltip();
    }
    if (UI::IsItemClicked(UI::MouseButton::Right) and GetApp().Editor is null)
    {
        if (!IsConvertingReplay)
        {
            @CurrentActiveMatch = Match;
            RenderMatchModifications = true;
            if (QuickConvert) 
            {
                IsConvertingReplay = true;
                HandleConvertGhostToReplay(CurrentActiveMatch);
            }
        } else
        {
            UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Please convert the currently active ghost or cancel the conversion!", vec4(0.6, 0, 0, 1));
        }
    }
}

void DownloadEmptyReplay()
{
    IsDownloadingEmptyReplay = true;

    auto Request = Net::HttpGet("https://download.dashmap.live/59ccbd15-ef8d-4450-b781-72161ade02b1/EmptyReplay.Replay.Gbx");
    Request.Start();

    while (!Request.Finished()) yield();
    

    if (IO::FolderExists(IO::FromUserGameFolder("Replays\\Replays")))
    {
        Request.SaveToFile(IO::FromUserGameFolder("Replays\\Replays\\EmptyReplay.Replay.Gbx"));
    }
    else
    {
        IO::CreateFolder(IO::FromUserGameFolder("Replays\\Replays"), true);
        Request.SaveToFile(IO::FromUserGameFolder("Replays\\Replays\\EmptyReplay.Replay.Gbx"));
    }

    UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Done downloading empty replay.", vec4(0, 0.7, 0, 1));

    Fids::UpdateTree(Fids::GetUserFolder("Replays"));
    IsEmptyReplayInstalled = Fids::GetUser("Replays/Replays/EmptyReplay.Replay.Gbx") !is null;

    IsDownloadingEmptyReplay = false;
}

void RenderMatchMod() 
{
    UI::Text("Currently active ghost: " + tostring(CurrentActiveMatch));
    UI::BeginDisabled(!IsEmptyReplayInstalled or IsConvertingReplay or IsDemo());

    if (UI::Button("Convert ghost to replay") and !IsConvertingReplay and !IsDemo())
    {
        HandleConvertGhostToReplay(CurrentActiveMatch);
    }
    UI::EndDisabled();
    if (IsConvertingReplay)
    {
        UI::Text("Please finish the conversion of the currently loaded replay.");
        if (UI::ButtonColored("Cancel current conversion", 0))
        {
            @CurrentActiveMatch = null;
            IsConvertingReplay = false;
            UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Conversion cancelled.", vec4(0.6, 0, 0, 1));
        }
    }
    if (IsDemo())
    {
        UI::Text("Demo players are unable to convert ghosts to replays due to nadeo limitations.");
    }
    if (IsDownloadingEmptyReplay)
    {
        UI::Text("Downloading EmptyReplay.Replay.Gbx...");
    }

    if (!IsEmptyReplayInstalled and !IsDemo())
    {
        UI::Text("To convert this ghost to a replay, you must download/create an EmptyReplay.Replay.Gbx file.");
        if (UI::Button("Check for EmptyReplay.Replay.Gbx in Replays/Replays/"))
        {
            Fids::UpdateTree(Fids::GetUserFolder("Replays"));
            IsEmptyReplayInstalled = Fids::GetUser("Replays/Replays/EmptyReplay.Replay.Gbx") !is null;
        }
        if (UI::Button("Download EmptyReplay") and !IsDownloadingEmptyReplay)
        {
            startnew(DownloadEmptyReplay);
        }
    }
}

void HandleConvertGhostToReplay(Match@ Match)
{
    IsConvertingReplay = true;
    auto EmptyReplay = LocateEmptyReplay();
    auto MatchChallenge = MapToChallenge(NumToMap(Match.MapNum));
    if (EmptyReplay is null)
    {
        UI::ShowNotification(GhostFinderLogo + "GhostFinder", "To edit this ghost, you must have an EmptyReplay.Replay.Gbx file (check capitalization!) in your Documents/Replays/Replays/ folder.");
        return;
    }
    else
    {
        @EmptyReplay.Challenge = MatchChallenge;
        UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Edit the empty replay and we will automatically import the ghost.", vec4(0, 0.7, 0, 1));
    }
}

CGameCtnMediaBlockGhost@ GetGhostFromEditor(CGameCtnMediaTracker@ Editor)
{
    for (uint i = 0; i < Editor.Tracks.Length; i++)
    {
        CGameCtnMediaTrack@ Track = Editor.Tracks[i];
        if (Track.Blocks.Length == 1)
        {
            CGameCtnMediaBlock@ Block = Track.Blocks[0];
            CGameCtnMediaBlockGhost@ GhostBlock = cast<CGameCtnMediaBlockGhost>(Block);
            if (GhostBlock !is null) return GhostBlock;
        }
    }
    return null;
}

CGameCtnMediaBlockTime@ GetTimeFromEditor(CGameCtnMediaTracker@ Editor)
{
   for (uint i = 0; i < Editor.Tracks.Length; i++)
    {
        CGameCtnMediaTrack@ Track = Editor.Tracks[i];
        if (Track.Blocks.Length == 1)
        {
            CGameCtnMediaBlock@ Block = Track.Blocks[0];
            CGameCtnMediaBlockTime@ TimeBlock = cast<CGameCtnMediaBlockTime>(Block);
            if (TimeBlock !is null) return TimeBlock;
        }
    }
    return null; 
}

bool IsDemo()
{
    return cast<CGameManiaPlanet>(GetApp()).ManiaPlanetScriptAPI.TmTurbo_IsDemo;
}

CGameCtnReplayRecord@ LocateEmptyReplay()
{
    auto File = Fids::GetUser("Replays/Replays/EmptyReplay.Replay.Gbx");
    if (File is null) return null;
    auto Nod = Fids::Preload(File);
    if (Nod is null) return null;
    return cast<CGameCtnReplayRecord>(Nod);
}

CGameCtnReplayRecordInfo@ LocateEmptyReplayInfo()
{
    auto App = GetApp();
    auto ReplayInfos = App.ReplayRecordInfos;
    for (uint i = 0; i < ReplayInfos.Length; i++)
    {
        auto ReplayInfo = ReplayInfos[i];
        if (ReplayInfo.Name == "EmptyReplay")
        {
            return ReplayInfo;
        }
    }
    return null;
}

void ForceLoadAllGhosts()
{
    Fids::UpdateTree(MapsGhostsFolder);
    Done = false;
}

string NextMap(const string &in map)
{
    int mapNum = Text::ParseInt(map);
    mapNum++;

    string output = tostring(mapNum);

    if (output.Length == 2)
    {
        output = "0" + output;
    }
    if (output.Length == 1)
    {
        output = "00" + output;
    }

    return output;
}

string NumToMap(int num)
{
    string output = tostring(num);

    if (output.Length == 2)
    {
        output = "0" + output;
    }
    if (output.Length == 1)
    {
        output = "00" + output;
    }

    return output;
}

string GetMapUIDFromGhost(CGameCtnGhost@ ghost)
{
    return MwId(Dev::GetOffsetUint32(ghost, OffsetGhostChallengeId)).GetName();
}

void DownloadAllGhosts()
{
    if (!Done) return;
    TotalDownloaded = 0;
    IsDownloadingGhosts = true;
    auto App = cast<CTrackMania>(GetApp());
    auto Menu = cast<CTrackManiaMenus>(App.MenuManager);
    auto ManiaApp = Menu.MenuCustom_CurrentManiaApp;
    auto ScoreMgr = ManiaApp.ScoreMgr;
    MwId UserId = App.ManiaPlanetScriptAPI.MasterServer_MSUsers[0].Id;

    for (uint i = 0; i < Final.Length; i++)
    {
        if (IsDownloadingGhosts == false) 
        {
            UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Ghost download has been cancelled.",  vec4(0.6, 0, 0, 1));
            return;
        }
        if (ScoreMgr.ScoreStatus_GetLocalStatus(UserId) == CGameScoreAndLeaderBoardManagerScript::ELocalScoreStatus::Loading)
        {
            i--;
            continue;
        }
        auto Task = ScoreMgr.Campaign_GetMapRecordGhost(UserId, Final[i]);
        while (Task.IsProcessing) yield();
        if (Task.ErrorType != CWebServicesTaskResult::ETaskErrorType::Success and Task.ErrorType != CWebServicesTaskResult::ETaskErrorType::DataManager) UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Could not load ghost for map #" + (i + 1) + " (" + tostring(Task.ErrorType) + ")", vec4(0.6, 0, 0, 1));
        // else UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Downloaded replay for #" + (i + 1));
        ScoreMgr.ReleaseTaskResult(Task.Id);
        TotalDownloaded = i + 1;
        yield(100); // required for turbo to not completely shit itself (thanks nado)
    }

    UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Done trying to load ghosts.");
    IsUIDExportFinished = false;
    Done = false;
    IsDownloadingGhosts = false;
    TotalDownloaded = 0;
}
