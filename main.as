class Match
{
    CGameCtnGhost@ Ghost = null;
    CSystemFidFile@ GhostFile = null;
    string GhostKind = "";
    string MapUID = "";
    string GhostFileName = "";
    string GhostTime = "";
    int GhostTimeInt = -1;
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

const string GhostFinderLogo = "\\$d3f" + Icons::Book + " \\$z";

UI::Font@ Monospace;

array<string> Final = {};
array<Match> Matches = {};

bool IsDownloadingEmptyReplay = false;
bool RenderMatchModifications = false;
Match@ CurrentActiveMatch = null;

bool IsConvertingReplay = false;

bool IsDownloadingGhosts = false;
int TotalDownloaded = 0;

[Setting hidden]
bool IsVisible = true;

// [Setting min=10 max=200 name="Match limit for warning" category="Settings"]
// uint S_WarnFewGhosts = 200;

[Setting min=1 max=100 name="Number of ghosts loaded per frame" category="Settings"]
uint MatchPerFrame = 20; // 20 worked best during testing on lower-end devices

[Setting hidden]
bool IsEmptyReplayInstalled = false;

[Setting name="Quick convert (quickly convert ghosts to replays)" category="Settings"]
bool QuickConvert = true;

bool MapsHaveLoaded = false;
bool Done = false;
bool IsUIDExportFinished = false;

bool EnableFilter = false;
bool filter = false;

int FilterMapNumber = 1;
int fmapnum = 1;

uint ProfileFolderNotFoundFailsafe = 0;
uint MapsGhostsFolderNotFoundFailsafe = 0;

CSystemFidsFolder@ ProfileFolder = null;
CSystemFidsFolder@ MapsGhostsFolder = null;

void RenderMenu() 
{
    if (UI::MenuItem(GhostFinderLogo + "GhostFinder", "", IsVisible)) {
        IsVisible = !IsVisible;
    } 
}

void ConvertReplay()
{
    if (IsConvertingReplay)
    {
        auto App = cast<CGameCtnApp>(GetApp());
        auto Editor = App.Editor;
        if (Editor !is null)
        {
            auto ReplayEditor = cast<CGameCtnMediaTracker>(Editor);
            if (ReplayEditor !is null)
            {
                CGameCtnMediaBlockGhost@ Ghost = GetGhostFromEditor(ReplayEditor);
                if (Ghost !is null)
                {
                    @Ghost.GhostModel = @CurrentActiveMatch.Ghost;

                    // it took me 3 hours to debug why this wasn't working properly, i forgot the .0 at the end of 1000.0
                    float Extension = (Ghost.GhostModel.RaceTime / 1000.0) + 0.5;

                    IO::SetClipboard(tostring(Extension));
                    UI::ShowNotification(GhostFinderLogo + "GhostFinder", "You can now paste the correct time value at the Time track's last key.");

                    for (uint i = 0; i < ReplayEditor.Tracks.Length; i++)
                    {
                        auto Track = ReplayEditor.Tracks[i];
                        if (Track.Blocks.Length == 0) continue; 
                        Track.Blocks[Track.Blocks.Length - 1].End = Extension;
                        yield();
                    }
                }

                IsConvertingReplay = false;
            }
        }
    }
}

void Render()
{
    if (!IsVisible) return;
    UI::PushFont(Monospace);
    if (RenderMatchModifications and !QuickConvert)
    {
        if (CurrentActiveMatch !is null)
        {
            if (UI::Begin(GhostFinderLogo + "Modify Ghost (GhostFinder)", RenderMatchModifications))
            {
                RenderMatchMod();
                UI::End();
            }
        }
    }
    if (UI::Begin("\\$d3f" + Icons::Book + " \\$zGhostFinder", IsVisible, UI::WindowFlags::NoCollapse))
    {
        UI::Text(!IsUIDExportFinished ? "Please wait..." : "Done!");
        
        if (!IsUIDExportFinished) UI::Separator();

        if (IsUIDExportFinished)
        {
            UI::SameLine();
            UI::Text("Total " + Matches.Length + " Ghost" + (Matches.Length == 1 ? "" : "s") + " found.");
            UI::Separator();
            // removed for being too annoying :iidiot:
            // if (Matches.Length < S_WarnFewGhosts)
            // {
            //     UI::Text("Only a few matches were found.\nPlease wait for the game to load during bootup and reload\nif this behaviour is unexpected.\nYou can also force load all of the ghosts in your MapsGhosts folder.");
            //     UI::Separator();
            // }
        }

        if (CurrentActiveMatch !is null and QuickConvert) UI::Text("Active match: " + CurrentActiveMatch.ToString());
        if (QuickConvert)
        {
            if (IsEmptyReplayInstalled) UI::Text("Quick convert is enabled." + (IsDemo() ? " Right-click matches to directly convert them to replays." : ""));
            if (IsConvertingReplay) 
            { 
                UI::Text("Please finish the conversion of the current match.");
                if (UI::ButtonColored("Cancel current conversion", 0))
                {
                    @CurrentActiveMatch = null;
                    IsConvertingReplay = false;
                    UI::ShowNotification(GhostFinderLogo + "GhostFinder", "Conversion cancelled.", vec4(0.6, 0, 0, 1));
                }
            }
            if (!IsEmptyReplayInstalled) 
            {
                UI::Text("Quick convert is enabled, but EmptyReplay is not installed. Please download it.");
                if (!IsDemo())
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
            if (IsDemo())
            {
                UI::Text("Demo players are unable to convert ghosts to replays due to Nadeo limitations.");
            }
            UI::Separator();
        }

        
        UI::BeginDisabled(IsDownloadingGhosts);
        if (UI::Button("Reload"))
        {
            Done = false;
            IsUIDExportFinished = false;
        }
        UI::SameLine();
        if (UI::Button("Force load all ghosts"))
        {
            ForceLoadAllGhosts();
            Done = false;
            IsUIDExportFinished = false;
        }
        if (UI::Button("Download all ghosts from cloud"))
        {
            startnew(DownloadAllGhosts);
        }
        UI::EndDisabled();
        if (IsDownloadingGhosts)
        {
            UI::Text("Please wait for ghosts download to finish.");
            UI::ProgressBar(TotalDownloaded / 200.0, vec2(-1, 0), TotalDownloaded + " / 200");
            if (UI::ButtonColored("Cancel download", 0))
            {
                IsDownloadingGhosts = false;
            }
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
            for (uint i = 0; i < Matches.Length; i++)
            {
                auto Match = Matches[i];
                if (Match.MapNum == fmapnum) RenderMatch(Match);
            }
        }
        else
        {
            for (uint i = 0; i < Matches.Length; i++)
            {
                auto Match = Matches[i];
                RenderMatch(Match);
            }
        }
        UI::End();
    }
    UI::PopFont();
}

void Main()
{
    Fids::UpdateTree(Fids::GetUserFolder("Replays"));
    IsEmptyReplayInstalled = Fids::GetUser("Replays/Replays/EmptyReplay.Replay.Gbx") !is null;
    @Monospace = @UI::LoadFont("DroidSansMono.ttf");
    while (true)
    {
        LoadMapsAndGhosts();
        ConvertReplay();
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
    for (uint i = 0; i < 200; i++)
    {
        string Location = MapToPath(MapStr);

        auto MapFid = Fids::GetUser("Maps/" + Location);
        auto MapNod = Fids::Preload(MapFid);
        if (MapNod is null)
        {
            warn("MapNod is null!");
            MapStr = NextMap(MapStr);
            continue;
        }
        auto Map = cast<CGameCtnChallenge>(MapNod);
        if (Map is null)
        {
            warn("Map is null!");
            MapStr = NextMap(MapStr);
            continue;
        }

        Final.InsertLast(Map.EdChallengeId);
        MapStr = NextMap(MapStr);
        if (i % MatchPerFrame == 0) yield();
    }
    auto UserFolder = Fids::GetUserFolder("");
    while (ProfileFolder is null)
    {
        for (uint i = 0; i < UserFolder.Trees.Length; i++)
        {
            auto Folder = cast<CSystemFidsFolder>(UserFolder.Trees[i]);
            if (Regex::IsMatch(Folder.DirName, ".{8}-.{4}-.{4}-.{4}-.{12}"))
            {
                @ProfileFolder = @Folder;
                break;
            }
        }
        if (ProfileFolder is null and ProfileFolderNotFoundFailsafe < 3) 
        {
            warn("ProfileFolder not found, retrying.");
            ProfileFolderNotFoundFailsafe++;
        }
        else if (ProfileFolder is null and ProfileFolderNotFoundFailsafe == 3)
        {
            warn("ProfileFolder not found for 3 consecutive frames, last warning.");
            ProfileFolderNotFoundFailsafe++;
        }
        yield();
    }
    while (MapsGhostsFolder is null)
    {
        for (uint i = 0; i < ProfileFolder.Trees.Length; i++)
        {
            auto Folder = cast<CSystemFidsFolder>(ProfileFolder.Trees[i]);
            if (tostring(Folder.DirName) == "MapsGhosts")
            {
                @MapsGhostsFolder = @Folder;
                break;
            }
        }
        if (MapsGhostsFolder is null and MapsGhostsFolderNotFoundFailsafe < 3) 
        {
            warn("MapsGhosts Folder not found, retrying.");
            MapsGhostsFolderNotFoundFailsafe++;
        }
        else if (MapsGhostsFolder is null and MapsGhostsFolderNotFoundFailsafe == 3)
        {
            warn("MapsGhosts Folder not found for 3 consecutive frames, last warning.");
            MapsGhostsFolderNotFoundFailsafe++;
        }
        yield();
    }
    ForceLoadAllGhosts();
    for (uint i = 0; i < MapsGhostsFolder.Leaves.Length; ++i)
    {
        auto File = cast<CSystemFidFile>(MapsGhostsFolder.Leaves[i]);
        if (File.FileName == "FileList.Gbx") continue;
        auto Nod = Fids::Preload(File);
        if (Nod is null) { warn(File.FileName + " is not Nod."); continue; }
        auto Ghost = cast<CGameCtnGhost>(Nod);
        if (Ghost is null) { warn(File.FileName + " is not Ghost."); continue; }
        string MapUIDFromGhost = GetMapUIDFromGhost(Ghost);
        int idx = Final.Find(MapUIDFromGhost);
        if (idx >= 0)
        {
            Match match = Match();
            match.GhostKind = Ghost.RecordingContext;
            match.GhostFileName = File.FileName;
            match.MapUID = MapUIDFromGhost;
            match.MapNum = idx + 1;
            match.idx = idx;
            @match.GhostFile = @File;
            match.GhostTime = Time::Format(Ghost.RaceTime);
            match.GhostTimeInt = Ghost.RaceTime;
            @match.Ghost = Ghost;
            Matches.InsertLast(match);
        }
        if (i % MatchPerFrame == 0) yield(); // double the match loading speed :business:
    }
    Done = true;
    IsUIDExportFinished = true;
}
