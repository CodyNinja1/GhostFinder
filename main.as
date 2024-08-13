class Match
{
    // CGameCtnReplayRecord@ Replay = null;
    CSystemFidFile@ GhostFile = null;
    string GhostKind = "";
    string MapUID = "";
    string GhostFileName = "";
    string GhostTime = "";
    int MapNum = 0;
    int idx = 0;

    Match(){}

    string ToString()
    {
        return GhostFileName + " -> #" + MapNum + " (" + GhostTime + ")";
    }

    string get_GhostSolo()
    {
        return GetSoloKind(GhostKind);
    }
}

UI::Font@ Monospace;

array<string> Final = {};
array<Match> Matches = {};

[Setting hidden]
bool IsVisible = true;

[Setting min=10 max=200 name="Match limit for warning" category="Settings"]
int S_WarnFewGhosts = 200;

bool MapsHaveLoaded = false;
bool Done = false;
bool IsUIDExportFinished = false;

bool EnableFilter = false;
bool filter = false;

int FilterMapNumber = 1;
int fmapnum = 1;

CGameCtnChallenge@ MapToChallenge(string map)
{
    return cast<CGameCtnChallenge>(Fids::Preload(Fids::GetUser("Maps/" + MapToPath(map))));
}

string MapToPath(string map)
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

string GetSoloKind(string GhostKind)
{
    if (GhostKind.StartsWith("Solo")) return "Solo";
    return "Double Driver";
}

void RenderMatch(Match Match)
{
    UI::PushFont(Monospace);
    UI::Text(tostring(Match));
    if (UI::IsItemHovered())
    {
        UI::BeginTooltip();
        UI::Text("UID " + Match.MapUID + " matched with map #" + Match.MapNum + "'s UID\nThis ghost was driven in " + Match.GhostSolo);
        UI::EndTooltip();
    }
    if (UI::IsItemClicked())
    {
        OpenExplorerPath(Match.GhostFile.FullFileName.SubStr(0, Match.GhostFile.FullFileName.Length - Match.GhostFileName.Length));
    }
    UI::PopFont();
}

void RenderMenu() 
{
    if (UI::MenuItem("\\$d3f" + Icons::Book + " \\$zGhostBinder", "", IsVisible)) {
        IsVisible = !IsVisible;
    } 
}

void Render()
{
    if (!IsVisible) return;
    if (UI::Begin("\\$d3f" + Icons::Book + " \\$zGhostBinder", IsVisible, UI::WindowFlags::NoCollapse))
    {
        UI::Text(!IsUIDExportFinished ? "Please wait..." : "Done!");

        if (!IsUIDExportFinished) UI::Separator();

        if (IsUIDExportFinished)
        {
            UI::SameLine();
            UI::Text("Total " + Matches.Length + " Ghost" + (Matches.Length == 1 ? "" : "s") + " found.");
            UI::Separator();
            if (Matches.Length < S_WarnFewGhosts)
            {
                UI::Text("Only a few matches were found.\nPlease wait for the game to load during bootup and reload\nif this behaviour is unexpected.");
                UI::Separator();
            }
        }

        if (UI::Button("Reload"))
        {
            Done = false;
        }
        UI::Separator();

        EnableFilter = UI::Checkbox("Find ghost by map number", filter);
        filter = EnableFilter;

        if (!EnableFilter) UI::Separator();

        if (EnableFilter)
        {
            if (fmapnum > 200)
            {
                fmapnum = 200;
            }
            if (fmapnum < 1)
            {
                fmapnum = 1;
            }
            FilterMapNumber = UI::InputInt("Map number", fmapnum);
            fmapnum = FilterMapNumber;

            UI::Separator();
            for (int i = 0; i < Matches.Length; i++)
            {
                auto Match = Matches[i];
                if (Match.MapNum == fmapnum) RenderMatch(Match);
            }
        }
        else
        {
            for (int i = 0; i < Matches.Length; i++)
            {
                auto Match = Matches[i];
                RenderMatch(Match);
            }
        }
        
        UI::End();
    }
}

string NextMap(string map)
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
    return MwId(Dev::GetOffsetUint32(ghost, 0x120)).GetName();
}

void Main()
{
    @Monospace = @UI::LoadFont("DroidSansMono.ttf");
    while (true)
    {
        LoadMapsAndGhosts();
        yield();
    }
}

void LoadMapsAndGhosts()
{
    if (Done) return;
    Matches = {};
    string MapStr = "001";
    while (!MapsHaveLoaded)
    {
        string Location = MapToPath(MapStr);

        auto MapFid = Fids::GetUser("Maps/" + Location);
        if (MapFid !is null)
        {
            MapsHaveLoaded = true;
            break;
        }
        yield();
    }
    for (int i = 0; i < 200; i++)
    {
        string Location = MapToPath(MapStr);

        auto MapFid = Fids::GetUser("Maps/" + Location);
        auto MapNod = Fids::Preload(MapFid);
        if (MapNod is null)
        {
            UI::ShowNotification("MapNod is null!");
            MapStr = NextMap(MapStr);
            continue;
        }
        auto Map = cast<CGameCtnChallenge>(MapNod);
        if (Map is null)
        {
            UI::ShowNotification("Map is null!");
            MapStr = NextMap(MapStr);
            continue;
        }

        Final.InsertLast(Map.EdChallengeId);
        MapStr = NextMap(MapStr);
        yield();
    }
    IsUIDExportFinished = true;
    CSystemFidsFolder@ ProfileFolder = null;
    CSystemFidsFolder@ MapsGhostsFolder = null;
    auto UserFolder = Fids::GetUserFolder("");
    while (ProfileFolder is null)
    {
        for (int i = 0; i < UserFolder.Trees.Length; i++)
        {
            auto Folder = cast<CSystemFidsFolder>(UserFolder.Trees[i]);
            if (Regex::IsMatch(Folder.DirName, ".{8}-.{4}-.{4}-.{4}-.{12}"))
            {
                @ProfileFolder = @Folder;
                break;
            }
        }
        if (ProfileFolder is null) warn("ProfileFolder not found, retrying.");
        yield();
    }
    while (MapsGhostsFolder is null)
    {
        for (int i = 0; i < ProfileFolder.Trees.Length; i++)
        {
            auto Folder = cast<CSystemFidsFolder>(ProfileFolder.Trees[i]);
            if (tostring(Folder.DirName) == "MapsGhosts")
            {
                @MapsGhostsFolder = @Folder;
                break;
            }
        }
        if (MapsGhostsFolder is null) warn("MapsGhosts folder not found, retrying");
        yield();
    }
    for (int i = 0; i < MapsGhostsFolder.Leaves.Length; ++i)
    {
        auto File = cast<CSystemFidFile>(MapsGhostsFolder.Leaves[i]);
        auto Nod = Fids::Preload(File);
        if (Nod is null) { error(File.FileName + " is not Nod."); continue; }
        auto Ghost = cast<CGameCtnGhost>(Nod);
        if (Ghost is null) { warn(File.FileName + " is not Ghost."); continue; }
        string MapUIDFromGhost = GetMapUIDFromGhost(Ghost);
        int idx = Final.Find(MapUIDFromGhost);
        if (idx >= 0)
        {
            // CGameCtnReplayRecord@ Replay = CGameCtnReplayRecord();
            // @Replay.HumanTimeToGameTimeFunc = null;
            // @Replay.Challenge = MapToChallenge(NumToMap(idx + 1));

            Match match = Match();
            match.GhostKind = Ghost.RecordingContext;
            match.GhostFileName = File.FileName;
            match.MapUID = MapUIDFromGhost;
            match.MapNum = idx + 1;
            match.idx = idx;
            // @match.Replay = @Replay;
            @match.GhostFile = @File;
            match.GhostTime = Time::Format(Ghost.RaceTime);
            Matches.InsertLast(match);
        }
    }
    Done = true;
}
