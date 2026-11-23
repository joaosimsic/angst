type ShellResult = { stdout: string; exitCode: number };
type ShellPromise = Promise<ShellResult> & {
    quiet: () => ShellPromise;
    nothrow: () => ShellPromise;
};
type Shell = (
    strings: TemplateStringsArray,
    ...values: unknown[]
) => ShellPromise;

type ToastInput = {
    body: {
        message: string;
        variant: "info" | "success" | "warning" | "error";
        duration?: number;
    };
    query?: { directory?: string };
};

type PluginInput = {
    $: Shell;
    directory: string;
    client?: {
        tui?: {
            showToast?: (input: ToastInput) => Promise<unknown>;
        };
    };
};

type CommandConfig = {
    template: string;
    description?: string;
};

type ConfigInput = {
    command?: Record<string, CommandConfig>;
};

type CommandInput = {
    command: string;
    sessionID?: string;
    arguments: string;
};

type Hooks = {
    config?: (input: ConfigInput) => Promise<void>;
    "command.execute.before"?: (input: CommandInput) => Promise<void>;
};

const COMMAND = "restart";
const DESCRIPTION =
    "Restart this project's OpenCode server (drops all attached clients)";

export const RestartPlugin = async ({
    $,
    directory,
    client,
}: PluginInput): Promise<Hooks> => {
    const toast = async (
        message: string,
        variant: ToastInput["body"]["variant"] = "error",
    ) => {
        try {
            await client?.tui?.showToast?.({
                body: { message, variant, duration: 8000 },
                query: { directory },
            });
        } catch {}
    };

    return {
        config: async (config) => {
            if (!config) return;
            config.command ??= {};
            config.command[COMMAND] = {
                description: DESCRIPTION,
                template: "Restart requested.",
            };
        },
        "command.execute.before": async (input) => {
            if (input?.command !== COMMAND) return;

            if (
                !process.env.OPENCODE_MUX_DIR ||
                !process.env.OPENCODE_MUX_PORT
            ) {
                await toast(
                    "Restart is only available with the opencode-mux server.",
                );
                return;
            }

            const unit = `opencode-restart-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
            try {
                const result =
                    await $`systemd-run --user --collect --unit ${unit} opencode-mux restart ${directory}`
                        .quiet()
                        .nothrow();
                if (result.exitCode !== 0) {
                    const detail = String(result.stdout).trim();
                    await toast(
                        detail || "Failed to schedule OpenCode server restart.",
                    );
                }
            } catch (error) {
                await toast(
                    error instanceof Error
                        ? error.message
                        : "Failed to schedule OpenCode server restart.",
                );
            }
        },
    };
};

export default RestartPlugin;
