import { useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { supabase } from "@/integrations/supabase/client";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Search, RefreshCw, Eye } from "lucide-react";
import { AdminAuditLog } from "@/types/supabase";

const ACTION_COLORS: Record<string, string> = {
  create: "bg-green-100 text-green-800",
  update: "bg-blue-100 text-blue-800",
  delete: "bg-red-100 text-red-800",
  ban: "bg-orange-100 text-orange-800",
  unban: "bg-yellow-100 text-yellow-800",
  approve: "bg-emerald-100 text-emerald-800",
  reject: "bg-rose-100 text-rose-800",
  refund: "bg-purple-100 text-purple-800",
};

function actionBadge(action: string) {
  const key = action.split("_")[0].toLowerCase();
  const cls = ACTION_COLORS[key] ?? "bg-gray-100 text-gray-800";
  return (
    <span className={`px-2 py-0.5 rounded text-xs font-semibold ${cls}`}>
      {action}
    </span>
  );
}

function formatDate(iso: string) {
  return new Date(iso).toLocaleString(undefined, {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function AuditLog() {
  const [search, setSearch] = useState("");
  const [tableFilter, setTableFilter] = useState<string>("all");
  const [selected, setSelected] = useState<AdminAuditLog | null>(null);

  const { data: logs = [], isLoading, refetch } = useQuery({
    queryKey: ["audit_log"],
    queryFn: async () => {
      const { data, error } = await supabase
        .from("admin_audit_log")
        .select("*")
        .order("created_at", { ascending: false })
        .limit(500);
      if (error) throw error;
      return data as AdminAuditLog[];
    },
  });

  // Distinct target tables for the filter dropdown
  const tables = Array.from(new Set(logs.map((l) => l.target_table))).sort();

  const filtered = logs.filter((log) => {
    const matchTable = tableFilter === "all" || log.target_table === tableFilter;
    const q = search.toLowerCase();
    const matchSearch =
      !q ||
      log.action.toLowerCase().includes(q) ||
      log.target_table.toLowerCase().includes(q) ||
      log.target_id?.toLowerCase().includes(q) ||
      log.admin_id?.toLowerCase().includes(q);
    return matchTable && matchSearch;
  });

  return (
    <div className="p-6 space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-foreground">Audit Log</h1>
          <p className="text-sm text-muted-foreground mt-1">
            All admin actions recorded in chronological order
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={() => refetch()}>
          <RefreshCw className="w-4 h-4 mr-2" />
          Refresh
        </Button>
      </div>

      {/* Filters */}
      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-muted-foreground" />
          <Input
            placeholder="Search by action, table, ID…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <Select value={tableFilter} onValueChange={setTableFilter}>
          <SelectTrigger className="w-48">
            <SelectValue placeholder="All tables" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">All tables</SelectItem>
            {tables.map((t) => (
              <SelectItem key={t} value={t}>
                {t}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      {/* Table */}
      <div className="rounded-lg border border-border overflow-hidden">
        <Table>
          <TableHeader>
            <TableRow className="bg-muted/50">
              <TableHead className="w-44">Timestamp</TableHead>
              <TableHead className="w-36">Action</TableHead>
              <TableHead className="w-40">Table</TableHead>
              <TableHead>Target ID</TableHead>
              <TableHead>Admin ID</TableHead>
              <TableHead className="w-16 text-center">Details</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {isLoading ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                  Loading…
                </TableCell>
              </TableRow>
            ) : filtered.length === 0 ? (
              <TableRow>
                <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                  No audit entries found
                </TableCell>
              </TableRow>
            ) : (
              filtered.map((log) => (
                <TableRow key={log.id} className="hover:bg-muted/30">
                  <TableCell className="text-xs text-muted-foreground whitespace-nowrap">
                    {formatDate(log.created_at)}
                  </TableCell>
                  <TableCell>{actionBadge(log.action)}</TableCell>
                  <TableCell>
                    <Badge variant="outline" className="font-mono text-xs">
                      {log.target_table}
                    </Badge>
                  </TableCell>
                  <TableCell className="font-mono text-xs text-muted-foreground truncate max-w-[160px]">
                    {log.target_id ?? "—"}
                  </TableCell>
                  <TableCell className="font-mono text-xs text-muted-foreground truncate max-w-[160px]">
                    {log.admin_id ?? "—"}
                  </TableCell>
                  <TableCell className="text-center">
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-7 w-7"
                      onClick={() => setSelected(log)}
                    >
                      <Eye className="w-4 h-4" />
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <p className="text-xs text-muted-foreground">
        Showing {filtered.length} of {logs.length} entries
      </p>

      {/* Detail Dialog */}
      <Dialog open={!!selected} onOpenChange={() => setSelected(null)}>
        <DialogContent className="max-w-2xl max-h-[80vh] overflow-y-auto">
          <DialogHeader>
            <DialogTitle>Audit Entry Detail</DialogTitle>
          </DialogHeader>
          {selected && (
            <div className="space-y-4 text-sm">
              <div className="grid grid-cols-2 gap-3">
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Action</p>
                  {actionBadge(selected.action)}
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Table</p>
                  <code className="text-xs bg-muted px-2 py-1 rounded">{selected.target_table}</code>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Target ID</p>
                  <code className="text-xs bg-muted px-2 py-1 rounded break-all">{selected.target_id ?? "—"}</code>
                </div>
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Admin ID</p>
                  <code className="text-xs bg-muted px-2 py-1 rounded break-all">{selected.admin_id ?? "—"}</code>
                </div>
                <div className="col-span-2">
                  <p className="text-xs text-muted-foreground mb-1">Timestamp</p>
                  <p>{formatDate(selected.created_at)}</p>
                </div>
              </div>

              {selected.before && (
                <div>
                  <p className="text-xs text-muted-foreground mb-1">Before</p>
                  <pre className="text-xs bg-muted p-3 rounded overflow-x-auto whitespace-pre-wrap">
                    {JSON.stringify(selected.before, null, 2)}
                  </pre>
                </div>
              )}

              {selected.after && (
                <div>
                  <p className="text-xs text-muted-foreground mb-1">After</p>
                  <pre className="text-xs bg-muted p-3 rounded overflow-x-auto whitespace-pre-wrap">
                    {JSON.stringify(selected.after, null, 2)}
                  </pre>
                </div>
              )}
            </div>
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
